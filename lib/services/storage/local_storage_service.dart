import '../../companion/models/companion_position.dart';
import '../../core/constants/app_constants.dart';
import 'storage_backend.dart';

/// Persists companion settings, position, and journal locally.
class LocalStorageService {
  LocalStorageService(this._backend);

  final StorageBackend _backend;

  static Future<LocalStorageService> create() async {
    final backend = await createStorageBackend();
    return LocalStorageService(backend);
  }

  /// Test helper — in-memory storage without touching disk.
  factory LocalStorageService.memory() {
    return LocalStorageService(InMemoryStorageBackend());
  }

  CompanionPosition loadPosition() {
    return CompanionPosition(
      x: _backend.getDouble(AppConstants.storageKeyPositionX) ??
          AppConstants.defaultPositionX,
      y: _backend.getDouble(AppConstants.storageKeyPositionY) ??
          AppConstants.defaultPositionY,
    );
  }

  Future<void> savePosition(CompanionPosition position) async {
    await _backend.setDouble(AppConstants.storageKeyPositionX, position.x);
    await _backend.setDouble(AppConstants.storageKeyPositionY, position.y);
  }

  bool loadEnabled({bool defaultValue = true}) {
    return _backend.getBool(AppConstants.storageKeyEnabled) ?? defaultValue;
  }

  Future<void> saveEnabled(bool enabled) async {
    await _backend.setBool(AppConstants.storageKeyEnabled, enabled);
  }

  bool loadIdleAnimations({bool defaultValue = true}) {
    return _backend.getBool(AppConstants.storageKeyIdleAnimations) ??
        defaultValue;
  }

  Future<void> saveIdleAnimations(bool enabled) async {
    await _backend.setBool(AppConstants.storageKeyIdleAnimations, enabled);
  }

  bool loadStartWithSystem({bool defaultValue = false}) {
    return _backend.getBool(AppConstants.storageKeyStartWithSystem) ??
        defaultValue;
  }

  Future<void> saveStartWithSystem(bool enabled) async {
    await _backend.setBool(AppConstants.storageKeyStartWithSystem, enabled);
  }

  double loadTransparency({double defaultValue = AppConstants.defaultTransparency}) {
    return (_backend.getDouble(AppConstants.storageKeyTransparency) ??
            defaultValue)
        .clamp(0.2, 1.0);
  }

  Future<void> saveTransparency(double value) async {
    await _backend.setDouble(
      AppConstants.storageKeyTransparency,
      value.clamp(0.2, 1.0),
    );
  }

  int loadCasesSolved({int defaultValue = 0}) {
    return _backend.getInt(AppConstants.storageKeyCasesSolved) ?? defaultValue;
  }

  Future<void> saveCasesSolved(int value) async {
    await _backend.setInt(AppConstants.storageKeyCasesSolved, value);
  }

  /// Returns today's mission progress, resetting if the calendar day changed.
  int loadMissionProgress() {
    final today = _todayKey();
    final savedDay = _backend.getString(AppConstants.storageKeyMissionDay);
    if (savedDay != today) {
      return 0;
    }
    return _backend.getInt(AppConstants.storageKeyMissionDone) ?? 0;
  }

  Future<void> saveMissionProgress(int progress) async {
    await _backend.setString(AppConstants.storageKeyMissionDay, _todayKey());
    await _backend.setInt(AppConstants.storageKeyMissionDone, progress);
  }

  bool loadHasSeenOnboarding({bool defaultValue = false}) {
    return _backend.getBool(AppConstants.storageKeyHasSeenOnboarding) ??
        defaultValue;
  }

  Future<void> saveHasSeenOnboarding(bool seen) async {
    await _backend.setBool(AppConstants.storageKeyHasSeenOnboarding, seen);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
