// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'storage_backend_base.dart';

Future<StorageBackend> createStorageBackend() async {
  return WebStorageBackend();
}

class WebStorageBackend implements StorageBackend {
  html.Storage get _storage => html.window.localStorage;

  @override
  double? getDouble(String key) {
    final value = _storage[key];
    if (value == null) return null;
    return double.tryParse(value);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    _storage[key] = value.toString();
  }

  @override
  bool? getBool(String key) {
    final value = _storage[key];
    if (value == null) return null;
    return value == 'true';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _storage[key] = value.toString();
  }

  @override
  int? getInt(String key) {
    final value = _storage[key];
    if (value == null) return null;
    return int.tryParse(value);
  }

  @override
  Future<void> setInt(String key, int value) async {
    _storage[key] = value.toString();
  }

  @override
  String? getString(String key) => _storage[key];

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }
}
