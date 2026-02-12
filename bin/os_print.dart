import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// OS printing support (Windows spooler / CUPS)
/// 
/// Provides platform-specific printing via OS print systems:
/// - Windows: Print Spooler API
/// - macOS/Linux: CUPS

/// Printer information from OS
class OsPrinterInfo {
  final String name;
  final String? description;
  final bool isDefault;

  OsPrinterInfo({
    required this.name,
    this.description,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'isDefault': isDefault,
    };
  }
}

/// Discover printers installed via OS
Future<List<OsPrinterInfo>> discoverOsPrinters() async {
  if (Platform.isWindows) {
    return _discoverWindowsPrinters();
  } else if (Platform.isMacOS || Platform.isLinux) {
    return _discoverCupsPrinters();
  }
  return [];
}

/// Print raw ESC/POS data via OS print system
Future<void> printToOs({
  required String printerName,
  required List<int> data,
}) async {
  if (Platform.isWindows) {
    await _printWindows(printerName: printerName, data: data);
  } else if (Platform.isMacOS || Platform.isLinux) {
    await _printCups(printerName: printerName, data: data);
  } else {
    throw UnsupportedError('OS printing not supported on this platform');
  }
}

// ============================================================================
// Windows Print Spooler
// ============================================================================

Future<List<OsPrinterInfo>> _discoverWindowsPrinters() async {
  // Use PowerShell to list printers (simpler than WinAPI FFI)
  try {
    final result = await Process.run(
      'powershell',
      [
        '-Command',
        r'Get-Printer | Select-Object Name, PrinterStatus, @{Name="IsDefault";Expression={if($_.Name -eq (Get-Printer | Where-Object {$_.Default}).Name){$True}else{$False}}} | ConvertTo-Json',
      ],
    );

    if (result.exitCode != 0) {
      return [];
    }

    // Parse JSON output
    final printers = <OsPrinterInfo>[];
    try {
      final jsonStr = result.stdout.toString().trim();
      if (jsonStr.isEmpty) return [];

      // PowerShell may return array or single object
      if (jsonStr.startsWith('[')) {
        // Array of printers
        final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
        for (final item in jsonList) {
          if (item is Map) {
            final name = item['Name']?.toString() ?? '';
            if (name.isNotEmpty) {
              printers.add(OsPrinterInfo(
                name: name,
                description: item['PrinterStatus']?.toString(),
                isDefault: item['IsDefault'] == true,
              ));
            }
          }
        }
      } else {
        // Single printer object
        final item = jsonDecode(jsonStr) as Map;
        final name = item['Name']?.toString() ?? '';
        if (name.isNotEmpty) {
          printers.add(OsPrinterInfo(
            name: name,
            description: item['PrinterStatus']?.toString(),
            isDefault: item['IsDefault'] == true,
          ));
        }
      }
    } catch (e) {
      // JSON parse failed, try alternative method
      return _discoverWindowsPrintersAlternative();
    }

    return printers;
  } catch (e) {
    return [];
  }
}

Future<List<OsPrinterInfo>> _discoverWindowsPrintersAlternative() async {
  // Alternative: Use wmic command (more reliable but older)
  try {
    final result = await Process.run(
      'wmic',
      ['printer', 'get', 'name,default', '/format:csv'],
    );

    if (result.exitCode != 0) return [];

    final printers = <OsPrinterInfo>[];
    final lines = result.stdout.toString().split('\n');
    
    for (final line in lines) {
      if (line.trim().isEmpty || line.contains('Node') || line.contains('Name')) continue;
      
      final parts = line.split(',');
      if (parts.length >= 2) {
        final name = parts[parts.length - 2].trim();
        final isDefault = parts.last.trim().toLowerCase() == 'true';
        
        if (name.isNotEmpty) {
          printers.add(OsPrinterInfo(
            name: name,
            isDefault: isDefault,
          ));
        }
      }
    }

    return printers;
  } catch (e) {
    return [];
  }
}

Future<void> _printWindows({
  required String printerName,
  required List<int> data,
}) async {
  // Use Windows copy command with PRN device or PowerShell
  // Create temp file with raw data
  final tempFile = File('${Directory.systemTemp.path}/hesett_print_${DateTime.now().millisecondsSinceEpoch}.raw');
  
  try {
    await tempFile.writeAsBytes(data);
    
    // Use PowerShell to send raw data to printer
    final result = await Process.run(
      'powershell',
      [
        '-Command',
        r'$printer = Get-Printer -Name "$printerName"; '
        r'if ($printer) { '
        r'  $content = [System.IO.File]::ReadAllBytes("${tempFile.path}"); '
        r'  [System.IO.File]::WriteAllBytes("\\\.\$printerName", $content) '
        r'} else { throw "Printer not found" }'.replaceAll(r'$printerName', printerName),
      ],
    );

    if (result.exitCode != 0) {
      throw Exception('Windows print failed: ${result.stderr}');
    }
  } finally {
    // Clean up temp file
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}

// ============================================================================
// CUPS (macOS / Linux)
// ============================================================================

Future<List<OsPrinterInfo>> _discoverCupsPrinters() async {
  try {
    // Use lpstat command to list printers
    final result = await Process.run(
      'lpstat',
      ['-p', '-d'],
    );

    if (result.exitCode != 0) {
      return [];
    }

    final printers = <OsPrinterInfo>[];
    final lines = result.stdout.toString().split('\n');
    String? defaultPrinter;
    
    // First, find default printer
    for (final line in lines) {
      if (line.startsWith('system default destination:')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          defaultPrinter = parts[1].trim();
        }
        break;
      }
    }
    
    // Parse printer list
    for (final line in lines) {
      if (line.startsWith('printer ') && line.contains(' is ')) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          final name = parts[1];
          final description = line.contains('idle') 
              ? 'Ready' 
              : line.contains('printing') 
                  ? 'Printing' 
                  : 'Unknown';
          
          printers.add(OsPrinterInfo(
            name: name,
            description: description,
            isDefault: name == defaultPrinter,
          ));
        }
      }
    }

    return printers;
  } catch (e) {
    return [];
  }
}

Future<void> _printCups({
  required String printerName,
  required List<int> data,
}) async {
  // Use lp command with raw data
  final process = await Process.start(
    'lp',
    [
      '-d',
      printerName,
      '-o',
      'raw', // Print raw data (no filtering)
    ],
    mode: ProcessStartMode.normal,
  );

  try {
    // Write raw data to stdin
    process.stdin.add(data);
    await process.stdin.close();

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final stderr = await process.stderr.transform(const SystemEncoding().decoder).join();
      throw Exception('CUPS print failed: $stderr');
    }
  } finally {
    process.stderr.drain();
    process.stdout.drain();
  }
}

