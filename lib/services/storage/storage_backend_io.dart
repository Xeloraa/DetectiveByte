import 'dart:convert';
import 'dart:io';

import 'storage_backend_base.dart';

Future<StorageBackend> createStorageBackend() async {
  final backend = FileStorageBackend();
  await backend.init();
  return backend;
}

class FileStorageBackend implements StorageBackend {
  late final File _file;
  Map<String, dynamic> _cache = {};

  Future<void> init() async {
    final baseDir = _appDataDirectory();
    final dir = Directory('$baseDir${Platform.pathSeparator}detective_byte');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _file = File('${dir.path}${Platform.pathSeparator}settings.json');
    if (await _file.exists()) {
      final contents = await _file.readAsString();
      _cache = jsonDecode(contents) as Map<String, dynamic>? ?? {};
    } else {
      _cache = {};
      await _persist();
    }
  }

  String _appDataDirectory() {
    if (Platform.isWindows) {
      return Platform.environment['APPDATA'] ??
          Platform.environment['LOCALAPPDATA'] ??
          Directory.current.path;
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? Directory.current.path;
      return '$home${Platform.pathSeparator}Library'
          '${Platform.pathSeparator}Application Support';
    }
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    return '$home${Platform.pathSeparator}.local'
        '${Platform.pathSeparator}share';
  }

  Future<void> _persist() async {
    await _file.writeAsString(jsonEncode(_cache));
  }

  @override
  double? getDouble(String key) => (_cache[key] as num?)?.toDouble();

  @override
  Future<void> setDouble(String key, double value) async {
    _cache[key] = value;
    await _persist();
  }

  @override
  bool? getBool(String key) => _cache[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async {
    _cache[key] = value;
    await _persist();
  }

  @override
  int? getInt(String key) => (_cache[key] as num?)?.toInt();

  @override
  Future<void> setInt(String key, int value) async {
    _cache[key] = value;
    await _persist();
  }

  @override
  String? getString(String key) => _cache[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _cache[key] = value;
    await _persist();
  }
}
