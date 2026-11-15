import '../core/levels.dart';
import 'doc_store.dart';
import 'models.dart';

/// Every persisted document and its schema version.
///
/// To change a document's shape: bump its `version`, add a migration from the
/// previous version in `migrations`, and add a test in
/// `test/data/persistence_test.dart`.
abstract final class Docs {
  static final settings = DocSpec<AppSettings>(
    key: 'sbm.settings',
    version: 1,
    parse: AppSettings.fromJson,
    encode: (s) => s.toJson(),
  );

  static final progress = DocSpec<PlayerProgress>(
    key: 'sbm.progress',
    version: 1,
    parse: PlayerProgress.fromJson,
    encode: (p) => p.toJson(),
  );

  static final ads = DocSpec<AdState>(
    key: 'sbm.ads',
    version: 1,
    parse: AdState.fromJson,
    encode: (a) => a.toJson(),
  );

  static final review = DocSpec<ReviewState>(
    key: 'sbm.review',
    version: 1,
    parse: ReviewState.fromJson,
    encode: (r) => r.toJson(),
  );

  static final purchases = DocSpec<PurchaseState>(
    key: 'sbm.purchases',
    version: 1,
    parse: PurchaseState.fromJson,
    encode: (p) => p.toJson(),
  );

  static final dailyCache = DocSpec<CachedDaily>(
    key: 'sbm.daily.cache',
    version: 1,
    parse: CachedDaily.fromJson,
    encode: (c) => c.toJson(),
  );

  /// Modes whose puzzle in progress is saved and can be resumed.
  static const savedModes = GameMode.values;

  static final Map<GameMode, DocSpec<SavedGame>> _games = {
    for (final m in savedModes)
      m: DocSpec<SavedGame>(
        key: 'sbm.game.${m.name}',
        version: 1,
        parse: SavedGame.fromJson,
        encode: (g) => g.toJson(),
      ),
  };

  /// The save slot for [mode]; `null` for modes that are never saved.
  static DocSpec<SavedGame>? game(GameMode mode) => _games[mode];

  /// All keys the app may read (SharedPreferences allow-list).
  static Set<String> get allKeys {
    final keys = <String>{
      settings.key,
      progress.key,
      ads.key,
      review.key,
      purchases.key,
      dailyCache.key,
      for (final g in _games.values) g.key,
    };
    return {...keys, for (final k in keys) '$k.bak'};
  }
}
