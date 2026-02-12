import 'dart:convert';
import 'dart:io';

/// Bridge configuration file manager
/// Stores configuration in ~/Library/Application Support/Hesett/PrintBridge/config.json
class BridgeConfig {
  static String get _configDir {
    if (Platform.isMacOS || Platform.isLinux) {
      return '${Platform.environment['HOME']}/Library/Application Support/Hesett/PrintBridge';
    } else if (Platform.isWindows) {
      return '${Platform.environment['APPDATA']}/Hesett/PrintBridge';
    }
    throw UnsupportedError('Platform not supported');
  }

  static File get _configFile => File('$_configDir/config.json');

  /// Load configuration from file
  static Map<String, dynamic> load() {
    try {
      final file = _configFile;
      if (!file.existsSync()) {
        return {};
      }
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>?;
      return json ?? {};
    } catch (e) {
      // If file is corrupted or unreadable, return empty config
      return {};
    }
  }

  /// Save configuration to file
  static void save(Map<String, dynamic> config) {
    try {
      final dir = Directory(_configDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = _configFile;
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(config),
      );
    } catch (e) {
      throw Exception('Failed to save bridge config: $e');
    }
  }

  /// Get restaurant ID from config
  static String? getRestaurantId() {
    final config = load();
    return config['restaurantId']?.toString();
  }

  /// Set restaurant ID in config
  static void setRestaurantId(String restaurantId) {
    final config = load();
    config['restaurantId'] = restaurantId;
    config['updatedAt'] = DateTime.now().toIso8601String();
    save(config);
  }

  /// Get device name from config
  static String? getDeviceName() {
    final config = load();
    return config['deviceName']?.toString();
  }

  /// Set device name in config
  static void setDeviceName(String deviceName) {
    final config = load();
    config['deviceName'] = deviceName;
    config['updatedAt'] = DateTime.now().toIso8601String();
    save(config);
  }

  /// Get Firebase project ID from config
  static String? getFirebaseProjectId() {
    final config = load();
    return config['firebaseProjectId']?.toString();
  }

  /// Set Firebase project ID in config
  static void setFirebaseProjectId(String projectId) {
    final config = load();
    config['firebaseProjectId'] = projectId;
    config['updatedAt'] = DateTime.now().toIso8601String();
    save(config);
  }

  /// Clear configuration (useful for testing)
  static void clear() {
    try {
      final file = _configFile;
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      // Ignore errors when clearing
    }
  }
}

