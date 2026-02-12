import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'usb_libusb.dart' show discoverUsbPrinters, printToUsb, isLibusbAvailable;
import 'os_print.dart' show discoverOsPrinters, printToOs;
import 'cloud_print_listener.dart';
import 'bridge_config.dart';

String _ts() => DateTime.now().toIso8601String();

void _log(String msg) {
  stdout.writeln('[${_ts()}] [HesettPrintBridge] $msg');
}

/// Get the local IP address for display
Future<String?> _getLocalIpAddress() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        // Prefer private IP addresses
        if (ip.startsWith('192.168.') || ip.startsWith('10.') || 
            (ip.startsWith('172.') && int.tryParse(ip.split('.')[1]) != null &&
             int.parse(ip.split('.')[1]) >= 16 && int.parse(ip.split('.')[1]) <= 31)) {
          return ip;
        }
      }
    }
    // Return any IPv4 if no private found
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        return addr.address;
      }
    }
  } catch (_) {}
  return null;
}

class _ParsedArgs {
  final int? port;
  final String? allowedOrigins;
  final bool? verbose;
  final String? host;
  // Cloud print configuration
  final String? restaurantId;
  final String? deviceName;
  final String? firebaseProjectId;

  const _ParsedArgs({
    required this.port,
    required this.allowedOrigins,
    required this.verbose,
    required this.host,
    this.restaurantId,
    this.deviceName,
    this.firebaseProjectId,
  });
}

_ParsedArgs _parseArgs(List<String> args) {
  int? port;
  String? allowedOrigins;
  bool? verbose;
  String? host;
  String? restaurantId;
  String? deviceName;
  String? firebaseProjectId;

  for (var i = 0; i < args.length; i++) {
    final a = args[i].trim();
    if (a.isEmpty) continue;

    String? takeValue() {
      if (i + 1 >= args.length) return null;
      i++;
      return args[i];
    }

    if (a == '--help' || a == '-h') {
      stdout.writeln('Hesett Print Bridge');
      stdout.writeln('');
      stdout.writeln('A local bridge that enables printing from the web dashboard.');
      stdout.writeln('Runs on the main POS computer and allows iPads/other devices to print.');
      stdout.writeln('');
      stdout.writeln('Usage: hesett_print_bridge [options]');
      stdout.writeln('');
      stdout.writeln('Options:');
      stdout.writeln('  --port <n>              WebSocket port (default 7171)');
      stdout.writeln('  --host <ip>             Bind address (default 0.0.0.0 = all interfaces)');
      stdout.writeln('  --allowed-origins <csv> Comma-separated Origin allowlist');
      stdout.writeln('  --verbose               Verbose logging');
      stdout.writeln('');
      stdout.writeln('Cloud Print Options (enable printing from iPads via Firebase):');
      stdout.writeln('  --restaurant-id <id>    Restaurant ID for cloud print queue');
      stdout.writeln('  --device-name <name>    Name for this bridge device (e.g. "Kitchen Mac")');
      stdout.writeln('  --firebase-project <id> Firebase project ID (default: lordwide-restaurant-ab977)');
      stdout.writeln('');
      stdout.writeln('Environment variables:');
      stdout.writeln('  HESETT_PRINT_BRIDGE_PORT');
      stdout.writeln('  HESETT_ALLOWED_ORIGINS');
      stdout.writeln('  HESETT_BRIDGE_VERBOSE=1');
      stdout.writeln('  HESETT_RESTAURANT_ID');
      stdout.writeln('  HESETT_DEVICE_NAME');
      stdout.writeln('  HESETT_FIREBASE_PROJECT');
      exit(0);
    }

    if (a.startsWith('--port=')) {
      port = int.tryParse(a.substring('--port='.length));
      continue;
    }
    if (a == '--port') {
      port = int.tryParse(takeValue() ?? '');
      continue;
    }

    if (a.startsWith('--host=')) {
      host = a.substring('--host='.length).trim();
      continue;
    }
    if (a == '--host') {
      host = (takeValue() ?? '').trim();
      continue;
    }

    if (a.startsWith('--allowed-origins=')) {
      allowedOrigins = a.substring('--allowed-origins='.length);
      continue;
    }
    if (a == '--allowed-origins') {
      allowedOrigins = takeValue();
      continue;
    }

    if (a == '--verbose') {
      verbose = true;
      continue;
    }
    if (a == '--quiet') {
      verbose = false;
      continue;
    }
    
    // Cloud print options
    if (a.startsWith('--restaurant-id=')) {
      restaurantId = a.substring('--restaurant-id='.length).trim();
      continue;
    }
    if (a == '--restaurant-id') {
      restaurantId = (takeValue() ?? '').trim();
      continue;
    }
    
    if (a.startsWith('--device-name=')) {
      deviceName = a.substring('--device-name='.length).trim();
      continue;
    }
    if (a == '--device-name') {
      deviceName = (takeValue() ?? '').trim();
      continue;
    }
    
    if (a.startsWith('--firebase-project=')) {
      firebaseProjectId = a.substring('--firebase-project='.length).trim();
      continue;
    }
    if (a == '--firebase-project') {
      firebaseProjectId = (takeValue() ?? '').trim();
      continue;
    }
  }

  return _ParsedArgs(
    port: port,
    allowedOrigins: allowedOrigins,
    verbose: verbose,
    host: host,
    restaurantId: restaurantId,
    deviceName: deviceName,
    firebaseProjectId: firebaseProjectId,
  );
}

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);

  // Default to 0.0.0.0 (all interfaces) to support iPad/network printing out of the box
  // Users can override with --host 127.0.0.1 if they want localhost-only
  final InternetAddress host;
  if (parsed.host != null && parsed.host!.isNotEmpty) {
    host = InternetAddress.tryParse(parsed.host!) ?? InternetAddress.anyIPv4;
  } else {
    host = InternetAddress.anyIPv4; // 0.0.0.0 - allows network connections
  }
  
  final port = parsed.port ?? int.tryParse(Platform.environment['HESETT_PRINT_BRIDGE_PORT'] ?? '') ?? 7171;

  final allowedOriginsEnv = (parsed.allowedOrigins ?? Platform.environment['HESETT_ALLOWED_ORIGINS'] ?? '').trim();
  final allowedOrigins = allowedOriginsEnv.isEmpty
      ? <String>[]
      : allowedOriginsEnv.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final verbose = parsed.verbose ?? (Platform.environment['HESETT_BRIDGE_VERBOSE'] ?? '').trim() == '1';

  final httpServer = await HttpServer.bind(host, port);
  final localIp = await _getLocalIpAddress();
  
  _log('Hesett Print Bridge is running!');
  _log('='.padRight(60, '='));
  _log('Listening on: ws://${host.address}:$port');
  if (localIp != null && host.address == '0.0.0.0') {
    _log('');
    _log('iPads and other devices can connect using:');
    _log('  ws://$localIp:$port');
  }
  _log('='.padRight(60, '='));
  
  if (allowedOrigins.isEmpty) {
    _log('WARNING: HESETT_ALLOWED_ORIGINS not set (any site can connect).');
  } else {
    _log('Allowed Origins: ${allowedOrigins.join(", ")}');
  }
  if (verbose) {
    _log('Verbose logging enabled (HESETT_BRIDGE_VERBOSE=1)');
  }
  
  // Cloud print listener - enables printing from iPads via Firebase
  // Priority: command-line > environment variable > config file
  var restaurantId = parsed.restaurantId ?? 
      Platform.environment['HESETT_RESTAURANT_ID'] ?? 
      BridgeConfig.getRestaurantId() ?? 
      '';
  var deviceName = parsed.deviceName ?? 
      Platform.environment['HESETT_DEVICE_NAME'] ?? 
      BridgeConfig.getDeviceName() ??
      '${Platform.localHostname} Bridge';
  var firebaseProjectId = parsed.firebaseProjectId ??
      Platform.environment['HESETT_FIREBASE_PROJECT'] ?? 
      BridgeConfig.getFirebaseProjectId() ??
      'lordwide-restaurant-ab977';
  
  CloudPrintListener? cloudPrintListener;
  
  // Helper function to start cloud print listener
  void startCloudPrintListener() {
    cloudPrintListener?.stop();
    
    if (restaurantId.isNotEmpty) {
      final deviceId = '${Platform.localHostname}-${DateTime.now().millisecondsSinceEpoch}';
      
      cloudPrintListener = CloudPrintListener(
        config: CloudPrintConfig(
          projectId: firebaseProjectId,
          restaurantId: restaurantId,
          deviceId: deviceId,
          deviceName: deviceName,
        ),
        log: _log,
      );
      // Poll every 1 second for faster response (reduces delay from ~15s to ~3-5s)
      cloudPrintListener!.start(interval: const Duration(seconds: 1));
      
      _log('');
      _log('☁️  Cloud Print enabled for restaurant: $restaurantId');
      _log('    Device: $deviceName');
      _log('    iPads can now print via Firebase (no WebSocket needed)');
    } else {
      _log('');
      _log('ℹ️  Cloud Print disabled (no restaurant ID configured)');
      _log('    Use setRestaurantId command or --restaurant-id to enable');
    }
  }
  
  // Start cloud print listener if restaurant ID is available
  startCloudPrintListener();
  _log('');

  await for (final req in httpServer) {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.badRequest
        ..write('WebSocket only')
        ..close();
      continue;
    }

    final remote = req.connectionInfo?.remoteAddress.address ?? 'unknown';
    final origin = req.headers.value('origin') ?? '';
    _log('WS upgrade request from $remote origin="$origin" path="${req.uri.path}"');
    
    // Check if origin is allowed - also auto-allow any localhost origin for dev convenience
    final isLocalhost = origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:');
    final isAllowed = allowedOrigins.isEmpty || allowedOrigins.contains(origin) || isLocalhost;
    
    if (!isAllowed) {
      req.response
        ..statusCode = HttpStatus.forbidden
        ..write('Origin not allowed')
        ..close();
      _log('Rejected origin: $origin');
      continue;
    }

    final socket = await WebSocketTransformer.upgrade(req);
    _log('Client connected from $remote');

    socket.listen((event) async {
      final String raw = event.toString();
      Map<String, dynamic> msg;
      try {
        msg = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        if (verbose) _log('Ignoring non-JSON message: $raw');
        return;
      }

      final id = msg['id'];
      if (id is! int) return;

      final type = msg['type']?.toString();
      if (verbose) _log('Request id=$id type="$type" keys=${msg.keys.toList()}');
      
      if (type == 'ping') {
        socket.add(jsonEncode({'id': id, 'ok': true}));
        return;
      }
      
      // getInfo command to retrieve bridge configuration
      if (type == 'getInfo') {
        // Detect IP fresh (network conditions might have changed)
        final currentIp = await _getLocalIpAddress();
        socket.add(jsonEncode({
          'id': id,
          'ok': true,
          'localIp': currentIp,
          'port': port,
          'restaurantId': restaurantId.isEmpty ? null : restaurantId,
        }));
        return;
      }
      
      // setRestaurantId command - saves restaurant ID to config file and restarts cloud print listener
      if (type == 'setRestaurantId') {
        final newRestaurantId = msg['restaurantId']?.toString();
        final newDeviceName = msg['deviceName']?.toString();
        
        if (newRestaurantId == null || newRestaurantId.isEmpty) {
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': 'restaurantId is required'}));
          return;
        }
        
        try {
          // Save to config file
          BridgeConfig.setRestaurantId(newRestaurantId);
          restaurantId = newRestaurantId;
          
          if (newDeviceName != null && newDeviceName.isNotEmpty) {
            BridgeConfig.setDeviceName(newDeviceName);
            deviceName = newDeviceName;
          }
          
          // Restart cloud print listener with new restaurant ID
          startCloudPrintListener();
          
          _log('setRestaurantId id=$id -> restaurantId=$restaurantId deviceName=$deviceName');
          socket.add(jsonEncode({
            'id': id,
            'ok': true,
            'restaurantId': restaurantId,
            'deviceName': deviceName,
          }));
        } catch (e) {
          _log('setRestaurantId id=$id FAIL error=$e');
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': e.toString()}));
        }
        return;
      }

      if (type == 'printRawTcp') {
        final ip = msg['ip']?.toString();
        final port = (msg['port'] is int) ? msg['port'] as int : int.tryParse('${msg['port']}') ?? 9100;
        final b64 = msg['dataB64']?.toString();
        if (ip == null || ip.isEmpty || b64 == null || b64.isEmpty) {
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': 'missing ip/dataB64'}));
          return;
        }

        try {
          final data = base64Decode(b64);
          _log('printRawTcp id=$id -> $ip:$port bytes=${data.length}');
          final sw = Stopwatch()..start();
          await _printToTcp(ip: ip, port: port, data: data);
          sw.stop();
          _log('printRawTcp id=$id OK (${sw.elapsedMilliseconds}ms)');
          socket.add(jsonEncode({'id': id, 'ok': true}));
        } catch (e) {
          _log('printRawTcp id=$id FAIL error=$e');
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': e.toString()}));
        }
        return;
      }

      if (type == 'discoverTcp9100') {
        final port = (msg['port'] is int) ? msg['port'] as int : int.tryParse('${msg['port']}') ?? 9100;
        try {
          _log('discoverTcp9100 id=$id port=$port starting');
          final prefix = await _guessLocalPrefix24();
          if (prefix == null) {
            _log('discoverTcp9100 id=$id FAIL no_local_ipv4');
            socket.add(jsonEncode({'id': id, 'ok': false, 'error': 'no_local_ipv4'}));
            return;
          }
          _log('discoverTcp9100 id=$id prefix=$prefix scanning /24');
          final sw = Stopwatch()..start();
          final ips = await _scanPrefixForOpenPort(prefix: prefix, port: port, verbose: verbose);
          sw.stop();
          _log('discoverTcp9100 id=$id done hits=${ips.length} (${sw.elapsedMilliseconds}ms)');
          socket.add(jsonEncode({'id': id, 'ok': true, 'prefix': prefix, 'ips': ips}));
        } catch (e) {
          _log('discoverTcp9100 id=$id FAIL error=$e');
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': e.toString()}));
        }
        return;
      }

      if (type == 'discoverUsb') {
        try {
          _log('discoverUsb id=$id starting');
          final sw = Stopwatch()..start();
          final printers = await _discoverUsbPrinters();
          sw.stop();
          _log('discoverUsb id=$id done found=${printers.length} (${sw.elapsedMilliseconds}ms)');
          socket.add(jsonEncode({'id': id, 'ok': true, 'printers': printers}));
        } catch (e) {
          _log('discoverUsb id=$id FAIL error=$e');
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': e.toString()}));
        }
        return;
      }

      if (type == 'printRawUsb') {
        final vendorId = (msg['vendorId'] is int) ? msg['vendorId'] as int : int.tryParse('${msg['vendorId']}');
        final productId = (msg['productId'] is int) ? msg['productId'] as int : int.tryParse('${msg['productId']}');
        final interface = (msg['interface'] is int) ? msg['interface'] as int : int.tryParse('${msg['interface']}') ?? 0;
        final outEndpoint = (msg['outEndpoint'] is int) ? msg['outEndpoint'] as int : int.tryParse('${msg['outEndpoint']}');
        final busNumber = (msg['busNumber'] is int) ? msg['busNumber'] as int : int.tryParse('${msg['busNumber']}');
        final deviceAddress = (msg['deviceAddress'] is int) ? msg['deviceAddress'] as int : int.tryParse('${msg['deviceAddress']}');
        final b64 = msg['dataB64']?.toString();
        
        if (vendorId == null || productId == null || outEndpoint == null || b64 == null || b64.isEmpty) {
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': 'missing vendorId/productId/outEndpoint/dataB64'}));
          return;
        }

        try {
          final data = base64Decode(b64);
          final location = (busNumber != null && deviceAddress != null) 
              ? ' bus=$busNumber addr=$deviceAddress'
              : '';
          _log('printRawUsb id=$id -> vendorId=$vendorId productId=$productId interface=$interface endpoint=$outEndpoint$location bytes=${data.length}');
          final sw = Stopwatch()..start();
          await _printToUsb(
            vendorId: vendorId, 
            productId: productId, 
            busNumber: busNumber,
            deviceAddress: deviceAddress,
            interface: interface, 
            outEndpoint: outEndpoint, 
            data: data
          );
          sw.stop();
          _log('printRawUsb id=$id OK (${sw.elapsedMilliseconds}ms)');
          socket.add(jsonEncode({'id': id, 'ok': true}));
        } catch (e) {
          _log('printRawUsb id=$id FAIL error=$e');
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': e.toString()}));
        }
        return;
      }

      if (type == 'discoverOsPrinters') {
        try {
          _log('discoverOsPrinters id=$id starting');
          final sw = Stopwatch()..start();
          final printers = await _discoverOsPrinters();
          sw.stop();
          _log('discoverOsPrinters id=$id done found=${printers.length} (${sw.elapsedMilliseconds}ms)');
          socket.add(jsonEncode({'id': id, 'ok': true, 'printers': printers}));
        } catch (e) {
          _log('discoverOsPrinters id=$id FAIL error=$e');
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': e.toString()}));
        }
        return;
      }

      if (type == 'printOs') {
        final printerName = msg['printerName']?.toString();
        final b64 = msg['dataB64']?.toString();
        
        if (printerName == null || printerName.isEmpty || b64 == null || b64.isEmpty) {
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': 'missing printerName/dataB64'}));
          return;
        }

        try {
          final data = base64Decode(b64);
          _log('printOs id=$id -> printer="$printerName" bytes=${data.length}');
          final sw = Stopwatch()..start();
          await _printToOs(printerName: printerName, data: data);
          sw.stop();
          _log('printOs id=$id OK (${sw.elapsedMilliseconds}ms)');
          socket.add(jsonEncode({'id': id, 'ok': true}));
        } catch (e) {
          _log('printOs id=$id FAIL error=$e');
          socket.add(jsonEncode({'id': id, 'ok': false, 'error': e.toString()}));
        }
        return;
      }

      socket.add(jsonEncode({'id': id, 'ok': false, 'error': 'unknown type'}));
    }, onDone: () {
      _log('Client disconnected');
    }, onError: (e) {
      _log('Socket error: $e');
    });
  }
}

Future<void> _printToTcp({
  required String ip,
  required int port,
  required List<int> data,
}) async {
  final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
  try {
    socket.add(data);
    await socket.flush();
  } finally {
    await socket.close();
  }
}

// ============================================================================
// USB Printing (via libusb FFI)
// ============================================================================

/// Discover USB printers and return interface/endpoint information
Future<List<Map<String, dynamic>>> _discoverUsbPrinters() async {
  try {
    if (!isLibusbAvailable()) {
      _log('libusb not available - USB discovery skipped');
      return [];
    }
    
    final printers = discoverUsbPrinters();
    return printers.map((p) => p.toJson()).toList();
  } catch (e) {
    _log('USB discovery error: $e');
    rethrow;
  }
}

/// Print raw ESC/POS data to USB printer
Future<void> _printToUsb({
  required int vendorId,
  required int productId,
  int? busNumber,
  int? deviceAddress,
  required int interface,
  required int outEndpoint,
  required List<int> data,
}) async {
  if (!isLibusbAvailable()) {
    throw UnsupportedError('libusb not available on this system');
  }
  
  // Run in isolate or sync call since libusb is synchronous
  printToUsb(
    vendorId: vendorId,
    productId: productId,
    busNumber: busNumber,
    deviceAddress: deviceAddress,
    interfaceNumber: interface,
    outEndpoint: outEndpoint,
    data: data,
  );
}

// ============================================================================
// OS Printing (Windows spooler / CUPS)
// ============================================================================

/// Discover printers installed via OS (Windows spooler, CUPS)
Future<List<Map<String, dynamic>>> _discoverOsPrinters() async {
  try {
    final printers = await discoverOsPrinters();
    return printers.map((p) => p.toJson()).toList();
  } catch (e) {
    _log('OS printer discovery error: $e');
    return [];
  }
}

/// Print raw ESC/POS data via OS print system
Future<void> _printToOs({
  required String printerName,
  required List<int> data,
}) async {
  await printToOs(printerName: printerName, data: data);
}

// ============================================================================
// Network Discovery
// ============================================================================

Future<String?> _guessLocalPrefix24() async {
  final ifaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );

  InternetAddress? best;
  for (final iface in ifaces) {
    for (final addr in iface.addresses) {
      final ip = addr.address;
      if (_isPrivateIpv4(ip)) {
        best = addr;
        break;
      }
    }
    if (best != null) break;
  }

  // Fallback: any IPv4
  best ??= ifaces.expand((i) => i.addresses).cast<InternetAddress?>().firstWhere(
        (a) => a != null,
        orElse: () => null,
      );

  if (best == null) return null;
  final parts = best.address.split('.');
  if (parts.length != 4) return null;
  return '${parts[0]}.${parts[1]}.${parts[2]}.';
}

bool _isPrivateIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final a = int.tryParse(parts[0]) ?? -1;
  final b = int.tryParse(parts[1]) ?? -1;
  if (a == 10) return true;
  if (a == 192 && b == 168) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  return false;
}

Future<List<String>> _scanPrefixForOpenPort({
  required String prefix,
  required int port,
  required bool verbose,
}) async {
  // Scan prefix.1..254 for a TCP connect on `port`.
  // Keep it reasonably fast with small timeouts + batching.
  const timeout = Duration(milliseconds: 180);
  const batchSize = 32;

  final hits = <String>[];
  final ips = <String>[for (var i = 1; i <= 254; i++) '$prefix$i'];

  var batchNo = 0;
  for (var start = 0; start < ips.length; start += batchSize) {
    batchNo++;
    final end = (start + batchSize < ips.length) ? start + batchSize : ips.length;
    final batch = ips.sublist(start, end);
    final futures = batch.map((ip) async {
      try {
        final s = await Socket.connect(ip, port, timeout: timeout);
        await s.close();
        return ip;
      } catch (_) {
        return null;
      }
    }).toList();
    final results = await Future.wait(futures);
    for (final ip in results) {
      if (ip != null) hits.add(ip);
    }
    if (verbose) {
      _log('scan progress: batch $batchNo ${(end).toString().padLeft(3)}/254 hits=${hits.length}');
    }
  }

  return hits;
}
