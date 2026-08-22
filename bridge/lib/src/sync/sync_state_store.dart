import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';

/// Records which manifest each device has finished applying.
///
/// One row per device in `sync_state`. The stored value is the
/// `generatedAtUtc` of the manifest the device actually applied, not the time
/// the report arrived: a device that downloaded everything from a manifest is
/// caught up as of that manifest, and later work is picked up next time.
class SyncStateStore {
  /// Creates a store over [library].
  const SyncStateStore({required this.library});

  /// The initialized master library this store writes to.
  final MasterLibrary library;

  /// Upserts the completed sync of [deviceId] and returns the stored time.
  ///
  /// [manifestGeneratedAtUtc] is the manifest the device applied and
  /// [nowUtc] only stamps the row's own bookkeeping column. The upsert runs
  /// inside a transaction, so a device either has the new watermark or keeps
  /// the previous one.
  DateTime recordCompletedSync({
    required String deviceId,
    required DateTime manifestGeneratedAtUtc,
    required DateTime nowUtc,
  }) {
    final stored = manifestGeneratedAtUtc.toUtc();
    final db = library.database;
    runInDatabaseTransaction(db, () {
      db.execute(
        'INSERT INTO sync_state (device_id, last_synced_at_utc, '
        'updated_at_utc) VALUES (?, ?, ?) '
        'ON CONFLICT(device_id) DO UPDATE SET '
        'last_synced_at_utc = excluded.last_synced_at_utc, '
        'updated_at_utc = excluded.updated_at_utc',
        <Object?>[
          deviceId,
          stored.toIso8601String(),
          nowUtc.toUtc().toIso8601String(),
        ],
      );
    });
    return stored;
  }
}
