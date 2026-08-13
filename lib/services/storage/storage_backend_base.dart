/// Shared storage contract for companion preferences.
abstract class StorageBackend {
  double? getDouble(String key);
  Future<void> setDouble(String key, double value);

  bool? getBool(String key);
  Future<void> setBool(String key, bool value);

  int? getInt(String key);
  Future<void> setInt(String key, int value);

  String? getString(String key);
  Future<void> setString(String key, String value);
}

/// In-memory backend for tests.
class InMemoryStorageBackend implements StorageBackend {
  final Map<String, Object> _data = {};

  @override
  double? getDouble(String key) => (_data[key] as num?)?.toDouble();

  @override
  Future<void> setDouble(String key, double value) async {
    _data[key] = value;
  }

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async {
    _data[key] = value;
  }

  @override
  int? getInt(String key) => (_data[key] as num?)?.toInt();

  @override
  Future<void> setInt(String key, int value) async {
    _data[key] = value;
  }

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }
}
