import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'kv_store.dart';

typedef DocParser<T> = T Function(Map<String, Object?> data);
typedef DocEncoder<T> = Map<String, Object?> Function(T value);
typedef DocMigration = Map<String, Object?> Function(Map<String, Object?> data);

/// Describes one versioned JSON document (settings, progress, a saved game…).
///
/// Stored format: `{"v": <schema version>, "data": {...}}`.
class DocSpec<T> {
  const DocSpec({
    required this.key,
    required this.version,
    required this.parse,
    required this.encode,
    this.migrations = const {},
  });

  final String key;

  /// Current schema version. Bump it whenever the shape of `data` changes
  /// and add a migration from the previous version.
  final int version;
  final DocParser<T> parse;
  final DocEncoder<T> encode;

  /// `migrations[n]` converts data from version `n` to version `n + 1`.
  final Map<int, DocMigration> migrations;

  String get backupKey => '$key.bak';
}

enum LoadSource { primary, backup, none, newerVersion }

class LoadResult<T> {
  const LoadResult(this.value, this.source);

  final T? value;
  final LoadSource source;
}

/// Reads and writes versioned documents safely.
///
/// * Missing or malformed data never crashes the app: the primary copy is
///   tried first, then the last known-good backup, then defaults.
/// * A value is encoded and re-parsed *before* it is written, so an invalid
///   value can never replace a valid save.
/// * Data written by a newer app version is never overwritten by an older one.
/// * Writes are asynchronous and coalesced, so saving never blocks the UI.
class DocStore {
  DocStore(this._kv);

  final KvStore _kv;
  final Set<String> _readOnlyKeys = {};
  final Map<String, Future<void>> _pending = {};

  KvStore get kv => _kv;

  LoadResult<T> load<T>(DocSpec<T> spec) {
    final primary = _decode(spec, _kv.getString(spec.key));
    if (primary.source == LoadSource.newerVersion) {
      _readOnlyKeys.add(spec.key);
      return primary;
    }
    if (primary.value != null) {
      // Refresh the backup with the copy that just loaded successfully.
      final raw = _kv.getString(spec.key);
      if (raw != null && _kv.getString(spec.backupKey) != raw) {
        unawaited(_kv.setString(spec.backupKey, raw));
      }
      return primary;
    }
    final backup = _decode(spec, _kv.getString(spec.backupKey));
    if (backup.value != null) {
      debugPrint('DocStore: restored ${spec.key} from backup');
      return LoadResult(backup.value, LoadSource.backup);
    }
    return LoadResult<T>(null, LoadSource.none);
  }

  LoadResult<T> _decode<T>(DocSpec<T> spec, String? raw) {
    if (raw == null || raw.isEmpty) return LoadResult<T>(null, LoadSource.none);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return LoadResult<T>(null, LoadSource.none);
      }
      final v = decoded['v'];
      final rawData = decoded['data'];
      if (v is! int || rawData is! Map<String, Object?>) {
        return LoadResult<T>(null, LoadSource.none);
      }
      if (v > spec.version) {
        return LoadResult<T>(null, LoadSource.newerVersion);
      }
      Map<String, Object?> data = rawData;
      var version = v;
      while (version < spec.version) {
        final migrate = spec.migrations[version];
        if (migrate == null) return LoadResult<T>(null, LoadSource.none);
        data = migrate(data);
        version++;
      }
      return LoadResult(spec.parse(data), LoadSource.primary);
    } catch (e) {
      debugPrint('DocStore: could not read ${spec.key}: $e');
      return LoadResult<T>(null, LoadSource.none);
    }
  }

  /// Validates and writes [value]. Returns `false` if the value failed
  /// validation or the document is read-only (written by a newer version).
  Future<bool> save<T>(DocSpec<T> spec, T value) async {
    if (_readOnlyKeys.contains(spec.key)) return false;
    final String raw;
    try {
      raw = jsonEncode({'v': spec.version, 'data': spec.encode(value)});
      // Round-trip check: never persist something we cannot read back.
      final check = jsonDecode(raw) as Map<String, Object?>;
      spec.parse(check['data'] as Map<String, Object?>);
    } catch (e) {
      debugPrint('DocStore: refusing to save invalid ${spec.key}: $e');
      return false;
    }
    // Chain writes per key so they land in order.
    final previous = _pending[spec.key] ?? Future<void>.value();
    final write = previous
        .catchError((Object _) {})
        .then((_) => _kv.setString(spec.key, raw));
    _pending[spec.key] = write;
    try {
      await write;
      return true;
    } catch (e) {
      debugPrint('DocStore: write failed for ${spec.key}: $e');
      return false;
    } finally {
      if (identical(_pending[spec.key], write)) _pending.remove(spec.key);
    }
  }

  /// Deletes a document and its backup. Queued after any pending write for
  /// the same key, so an earlier save can never resurrect deleted data.
  Future<void> delete<T>(DocSpec<T> spec) async {
    if (_readOnlyKeys.contains(spec.key)) return;
    await deleteKey(spec.key);
  }

  Future<void> deleteKey(String key) async {
    final previous = _pending[key] ?? Future<void>.value();
    final op = previous.catchError((Object _) {}).then((_) async {
      await _kv.remove(key);
      await _kv.remove('$key.bak');
    });
    _pending[key] = op;
    try {
      await op;
    } catch (e) {
      debugPrint('DocStore: delete failed for $key: $e');
    } finally {
      if (identical(_pending[key], op)) _pending.remove(key);
    }
  }

  /// Waits for all queued writes (used when the app goes to background).
  Future<void> flush() async {
    final writes = List<Future<void>>.of(_pending.values);
    for (final w in writes) {
      try {
        await w;
      } catch (_) {
        // Failures were already logged by save(); flushing must not throw.
      }
    }
  }
}
