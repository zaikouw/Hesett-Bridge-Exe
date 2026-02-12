import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'os_print.dart' as os_print;

/// Configuration for cloud printing
class CloudPrintConfig {
  final String projectId;
  final String restaurantId;
  final String deviceId;
  final String deviceName;
  final String? apiKey;  // Optional Firebase API key for authentication
  
  CloudPrintConfig({
    required this.projectId,
    required this.restaurantId,
    required this.deviceId,
    required this.deviceName,
    this.apiKey,
  });
}

/// Cloud print job data parsed from Firestore
class CloudPrintJob {
  final String id;
  final String status;
  final Map<String, dynamic> target;
  final String payloadB64;
  final int paperWidth;
  final int attempts;
  final int maxAttempts;
  final String? orderId;
  final String? error;
  
  CloudPrintJob({
    required this.id,
    required this.status,
    required this.target,
    required this.payloadB64,
    this.paperWidth = 80,
    this.attempts = 0,
    this.maxAttempts = 3,
    this.orderId,
    this.error,
  });
  
  factory CloudPrintJob.fromFirestoreDoc(String id, Map<String, dynamic> fields) {
    String getStringValue(Map<String, dynamic>? field) {
      if (field == null) return '';
      return field['stringValue']?.toString() ?? '';
    }
    
    int getIntValue(Map<String, dynamic>? field) {
      if (field == null) return 0;
      return int.tryParse(field['integerValue']?.toString() ?? '0') ?? 0;
    }
    
    Map<String, dynamic> getMapValue(Map<String, dynamic>? field) {
      if (field == null) return {};
      final mapValue = field['mapValue'];
      if (mapValue == null) return {};
      final fields = mapValue['fields'];
      if (fields == null) return {};
      
      final result = <String, dynamic>{};
      for (final entry in (fields as Map).entries) {
        final key = entry.key.toString();
        final value = entry.value as Map<String, dynamic>;
        if (value.containsKey('stringValue')) {
          result[key] = value['stringValue'];
        } else if (value.containsKey('integerValue')) {
          result[key] = int.tryParse(value['integerValue'].toString()) ?? 0;
        }
      }
      return result;
    }
    
    return CloudPrintJob(
      id: id,
      status: getStringValue(fields['status']),
      target: getMapValue(fields['target']),
      payloadB64: getStringValue(fields['payloadB64']),
      paperWidth: getIntValue(fields['paperWidth']),
      attempts: getIntValue(fields['attempts']),
      maxAttempts: getIntValue(fields['maxAttempts']),
      orderId: getStringValue(fields['orderId']),
      error: getStringValue(fields['error']),
    );
  }
  
  Uint8List get payloadBytes => base64Decode(payloadB64);
  
  String get targetType => target['type']?.toString() ?? 'lan';
  String? get lanIp => target['ip']?.toString();
  int get lanPort => (target['port'] is int) ? target['port'] as int : 9100;
  String? get printerName => target['printerName']?.toString();
}

/// Listener that polls Firestore for cloud print jobs
class CloudPrintListener {
  final CloudPrintConfig config;
  final HttpClient _httpClient = HttpClient();
  Timer? _pollTimer;
  bool _processing = false;
  
  final void Function(String message) log;
  
  CloudPrintListener({
    required this.config,
    required this.log,
  });
  
  String get _firestoreBaseUrl => 
    'https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents';
  
  String get _printQueuePath => 
    'restaurants/${config.restaurantId}/printQueue';
  
  /// Start polling for cloud print jobs
  void start({Duration interval = const Duration(seconds: 3)}) {
    log('[CloudPrint] Starting cloud print listener');
    log('[CloudPrint] Project ID: ${config.projectId}');
    log('[CloudPrint] Restaurant ID: ${config.restaurantId}');
    log('[CloudPrint] Device: ${config.deviceName} (${config.deviceId})');
    log('[CloudPrint] Polling interval: ${interval.inSeconds}s');
    
    _pollTimer = Timer.periodic(interval, (_) => _pollForJobs());
    
    // Also poll immediately
    _pollForJobs();
  }
  
  /// Stop polling
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    log('[CloudPrint] Stopped cloud print listener');
  }
  
  /// Poll Firestore for queued jobs
  Future<void> _pollForJobs() async {
    if (_processing) return;
    
    try {
      final jobs = await _fetchQueuedJobs();
      
      if (jobs.isNotEmpty) {
        // Process all jobs
        for (final job in jobs) {
          await _processJob(job);
        }
        
        // Immediately poll again in case more jobs were queued while processing
        // This reduces delay for multiple jobs or jobs queued during processing
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_processing) {
            _pollForJobs();
          }
        });
      }
    } catch (e) {
      // Don't spam logs on connection errors
      if (e.toString().contains('SocketException')) {
        // Network error, will retry on next poll
      } else {
        log('[CloudPrint] Poll error: $e');
      }
    }
  }
  
  /// Fetch queued jobs from Firestore using REST API
  Future<List<CloudPrintJob>> _fetchQueuedJobs() async {
    // Use runQuery to filter by status
    final queryUrl = '$_firestoreBaseUrl:runQuery';
    
    final queryBody = {
      'structuredQuery': {
        'from': [{'collectionId': 'printQueue'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'status'},
            'op': 'EQUAL',
            'value': {'stringValue': 'queued'}
          }
        },
        'limit': 20
        // Note: Removed orderBy to avoid requiring a composite index
        // Jobs will be processed in the order they're returned
      }
    };
    
    final parentPath = 'projects/${config.projectId}/databases/(default)/documents/restaurants/${config.restaurantId}';
    final request = await _httpClient.postUrl(
      Uri.parse('$queryUrl?parent=$parentPath${_apiKeyParam}'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(queryBody));
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        // Collection doesn't exist yet, that's fine
        return [];
      }
      throw Exception('Firestore query failed: ${response.statusCode} - $responseBody');
    }
    
    final results = jsonDecode(responseBody) as List;
    final jobs = <CloudPrintJob>[];
    
    for (final result in results) {
      final doc = result['document'];
      if (doc == null) continue;
      
      final name = doc['name']?.toString() ?? '';
      final docId = name.split('/').last;
      final fields = doc['fields'] as Map<String, dynamic>? ?? {};
      
      jobs.add(CloudPrintJob.fromFirestoreDoc(docId, fields));
    }
    
    return jobs;
  }
  
  String get _apiKeyParam => config.apiKey != null ? '&key=${config.apiKey}' : '';
  
  /// Process a single print job
  Future<void> _processJob(CloudPrintJob job) async {
    _processing = true;
    
    try {
      log('[CloudPrint] Processing job ${job.id} (attempt ${job.attempts + 1}/${job.maxAttempts})');
      
      // Try to claim the job
      final claimed = await _claimJob(job.id);
      if (!claimed) {
        log('[CloudPrint] Job ${job.id} already claimed by another device');
        return;
      }
      
      // Print based on target type
      bool success = false;
      String? error;
      
      if (job.targetType == 'lan') {
        // LAN printing via TCP 9100
        final ip = job.lanIp;
        final port = job.lanPort;
        
        if (ip == null || ip.isEmpty) {
          error = 'No LAN IP configured';
        } else {
          try {
            success = await _printToLan(ip, port, job.payloadBytes);
          } catch (e) {
            error = 'LAN print error: $e';
          }
        }
      } else if (job.targetType == 'osPrinter') {
        // OS printing via CUPS/Windows Spooler
        final printerName = job.printerName;
        
        if (printerName == null || printerName.isEmpty) {
          error = 'No printer name specified';
        } else {
          try {
            await os_print.printToOs(printerName: printerName, data: job.payloadBytes);
            success = true;
          } catch (e) {
            error = 'OS print error: $e';
          }
        }
      } else {
        error = 'Unknown target type: ${job.targetType}';
      }
      
      // Update job status
      if (success) {
        await _markPrinted(job.id);
        log('[CloudPrint] ✅ Job ${job.id} printed successfully');
      } else {
        await _markFailed(job.id, error ?? 'Unknown error', job.attempts + 1, job.maxAttempts);
        log('[CloudPrint] ❌ Job ${job.id} failed: $error');
      }
    } finally {
      _processing = false;
    }
  }
  
  /// Claim a job (set status to printing)
  Future<bool> _claimJob(String jobId) async {
    try {
      final docUrl = '$_firestoreBaseUrl/$_printQueuePath/$jobId${_apiKeyParam.isNotEmpty ? '?${_apiKeyParam.substring(1)}' : ''}';
      
      // First check if still queued
      final getRequest = await _httpClient.getUrl(Uri.parse(docUrl));
      final getResponse = await getRequest.close();
      final getBody = await getResponse.transform(utf8.decoder).join();
      
      if (getResponse.statusCode != 200) return false;
      
      final doc = jsonDecode(getBody);
      final status = doc['fields']?['status']?['stringValue'];
      if (status != 'queued') return false;
      
      // Update to printing
      final updateUrl = '$docUrl?updateMask.fieldPaths=status&updateMask.fieldPaths=claimedBy&updateMask.fieldPaths=claimedByName&updateMask.fieldPaths=claimedAt&updateMask.fieldPaths=attempts';
      
      final attempts = int.tryParse(doc['fields']?['attempts']?['integerValue']?.toString() ?? '0') ?? 0;
      
      final patchBody = {
        'fields': {
          'status': {'stringValue': 'printing'},
          'claimedBy': {'stringValue': config.deviceId},
          'claimedByName': {'stringValue': config.deviceName},
          'claimedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          'attempts': {'integerValue': (attempts + 1).toString()},
        }
      };
      
      final patchRequest = await _httpClient.patchUrl(Uri.parse(updateUrl));
      patchRequest.headers.contentType = ContentType.json;
      patchRequest.write(jsonEncode(patchBody));
      
      final patchResponse = await patchRequest.close();
      return patchResponse.statusCode == 200;
    } catch (e) {
      log('[CloudPrint] Claim error: $e');
      return false;
    }
  }
  
  /// Mark job as printed
  Future<void> _markPrinted(String jobId) async {
    try {
      final docUrl = '$_firestoreBaseUrl/$_printQueuePath/$jobId';
      final updateUrl = '$docUrl?updateMask.fieldPaths=status&updateMask.fieldPaths=printedAt&updateMask.fieldPaths=error${_apiKeyParam}';
      
      final patchBody = {
        'fields': {
          'status': {'stringValue': 'printed'},
          'printedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
          'error': {'nullValue': null},
        }
      };
      
      final request = await _httpClient.patchUrl(Uri.parse(updateUrl));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(patchBody));
      await request.close();
    } catch (e) {
      log('[CloudPrint] Error marking printed: $e');
    }
  }
  
  /// Mark job as failed (or re-queue for retry)
  Future<void> _markFailed(String jobId, String error, int attempts, int maxAttempts) async {
    try {
      final docUrl = '$_firestoreBaseUrl/$_printQueuePath/$jobId';
      
      if (attempts < maxAttempts) {
        // Re-queue for retry
        final updateUrl = '$docUrl?updateMask.fieldPaths=status&updateMask.fieldPaths=claimedBy&updateMask.fieldPaths=claimedByName&updateMask.fieldPaths=claimedAt&updateMask.fieldPaths=error${_apiKeyParam}';
        
        final patchBody = {
          'fields': {
            'status': {'stringValue': 'queued'},
            'claimedBy': {'nullValue': null},
            'claimedByName': {'nullValue': null},
            'claimedAt': {'nullValue': null},
            'error': {'stringValue': 'Retry: $error'},
          }
        };
        
        final request = await _httpClient.patchUrl(Uri.parse(updateUrl));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(patchBody));
        await request.close();
      } else {
        // Mark as permanently failed
        final updateUrl = '$docUrl?updateMask.fieldPaths=status&updateMask.fieldPaths=error${_apiKeyParam}';
        
        final patchBody = {
          'fields': {
            'status': {'stringValue': 'failed'},
            'error': {'stringValue': error},
          }
        };
        
        final request = await _httpClient.patchUrl(Uri.parse(updateUrl));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(patchBody));
        await request.close();
      }
    } catch (e) {
      log('[CloudPrint] Error marking failed: $e');
    }
  }
  
  /// Print to LAN printer via TCP 9100. Always close socket to avoid "too many open files".
  Future<bool> _printToLan(String ip, int port, Uint8List data) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      socket.add(data);
      await socket.flush();
      return true;
    } catch (e) {
      log('[CloudPrint] LAN print to $ip:$port failed: $e');
      return false;
    } finally {
      await socket?.close();
    }
  }
}

