import 'package:shared_preferences/shared_preferences.dart';

/// Minimal string key-value storage used by the repositories.
///
/// Keeping this interface tiny lets tests use [MemoryKvStore] and lets the
/// storage backend change later without touching game code.
abstract class KvStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
  Set<String> get keys;
}

/// In-memory store for tests and as a last-resort fallback if platform
/// storage is unavailable (progress then lasts only for the session).
class MemoryKvStore implements KvStore {
  MemoryKvStore([Map<String, String>? initial])
    : _data = Map<String, String>.of(initial ?? const {});

  final Map<String, String> _data;

  @override
  String? getString(String key) => _data[key];

  @override
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  @override
  Set<String> get keys => _data.keys.toSet();
}

/// Platform-backed store (Android DataStore / iOS NSUserDefaults) through
/// `shared_preferences`. Reads are served from an in-memory cache, so they
/// never block the UI; writes are asynchronous.
class PrefsKvStore implements KvStore {
  PrefsKvStore._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<PrefsKvStore> open(Set<String> allowList) async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(allowList: allowList),
    );
    return PrefsKvStore._(prefs);
  }

  @override
  String? getString(String key) {
    final v = _prefs.get(key);
    return v is String ? v : null;
  }

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Set<String> get keys => _prefs.keys;
}
