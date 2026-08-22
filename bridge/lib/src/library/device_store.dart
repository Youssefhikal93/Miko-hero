import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:uuid/uuid.dart';

/// One paired device as persisted in the master library.
class PairedDevice {
  /// Creates a read-only device view.
  const PairedDevice({
    required this.id,
    required this.name,
    required this.createdAtUtc,
    this.revokedAtUtc,
  });

  /// Stable identifier of the device row.
  final String id;

  /// Human-readable device name chosen during pairing.
  final String name;

  /// When the device was paired.
  final DateTime createdAtUtc;

  /// When access was revoked, or `null` while the device stays trusted.
  final DateTime? revokedAtUtc;

  /// Whether this device may still authenticate.
  bool get isActive => revokedAtUtc == null;
}

/// Persists and verifies paired devices in the `devices` table.
///
/// Only SHA-256 digests of bearer tokens are ever stored; presented tokens
/// are verified by re-hashing and comparing digests in constant time.
class DeviceStore {
  /// Creates a store operating on [library]'s database.
  DeviceStore({required this._library, this._uuid = const Uuid()});

  final MasterLibrary _library;
  final Uuid _uuid;

  /// Registers a new active device with [name], storing only the
  /// [tokenHash] (lowercase hex SHA-256 of the bearer token).
  ///
  /// The insert runs inside a transaction. Returns the created view.
  PairedDevice registerDevice({
    required String name,
    required String tokenHash,
  }) {
    final db = _library.database;
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    runInDatabaseTransaction(db, () {
      db.execute(
        'INSERT INTO devices '
        '(id, device_name, token_hash, revoked_at_utc, created_at_utc, updated_at_utc) '
        'VALUES (?, ?, ?, NULL, ?, ?)',
        <Object?>[id, name, tokenHash, now, now],
      );
    });
    return PairedDevice(id: id, name: name, createdAtUtc: DateTime.parse(now));
  }

  /// Lists all devices oldest first, including revoked ones.
  List<PairedDevice> listDevices() {
    final db = _library.database;
    final rows = db.select(
      'SELECT id, device_name, created_at_utc, revoked_at_utc '
      'FROM devices ORDER BY created_at_utc ASC',
    );
    return rows
        .map(
          (row) => PairedDevice(
            id: row['id']! as String,
            name: row['device_name']! as String,
            createdAtUtc: DateTime.parse(row['created_at_utc']! as String),
            revokedAtUtc: row['revoked_at_utc'] == null
                ? null
                : DateTime.parse(row['revoked_at_utc']! as String),
          ),
        )
        .toList(growable: false);
  }

  /// Finds the active device whose stored token hash matches
  /// [presentedTokenHashHex] in constant time, or `null`.
  PairedDevice? findActiveByTokenHash(String presentedTokenHashHex) {
    final db = _library.database;
    final rows = db.select(
      'SELECT id, device_name, created_at_utc, revoked_at_utc, token_hash '
      'FROM devices',
    );
    for (final row in rows) {
      if (row['revoked_at_utc'] != null) {
        continue;
      }
      final storedHash = row['token_hash']! as String;
      if (!constantTimeHexDigestEquals(presentedTokenHashHex, storedHash)) {
        continue;
      }
      return PairedDevice(
        id: row['id']! as String,
        name: row['device_name']! as String,
        createdAtUtc: DateTime.parse(row['created_at_utc']! as String),
      );
    }
    return null;
  }

  /// Revokes the active device matching [presentedTokenHashHex].
  ///
  /// Returns whether a matching active device was found and revoked.
  bool revokeByTokenHash(String presentedTokenHashHex) {
    final db = _library.database;
    final target = findActiveByTokenHash(presentedTokenHashHex);
    if (target == null) {
      return false;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    runInDatabaseTransaction(db, () {
      db.execute(
        'UPDATE devices SET revoked_at_utc = ?, updated_at_utc = ? WHERE id = ?',
        <Object?>[now, now, target.id],
      );
    });
    return true;
  }
}
