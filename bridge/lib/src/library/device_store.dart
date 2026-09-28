import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// One paired device as persisted in the master library.
class PairedDevice {
  /// Creates a read-only device view.
  const PairedDevice({
    required this.id,
    required this.name,
    required this.createdAtUtc,
    this.lastSeenAtUtc,
    this.revokedAtUtc,
  });

  /// Stable identifier of the device row.
  final String id;

  /// Human-readable device name chosen during pairing.
  final String name;

  /// When the device was paired.
  final DateTime createdAtUtc;

  /// When this device last presented a valid token, or `null` if never.
  ///
  /// A device paired by a build older than schema version 3, or paired but
  /// never used since, truthfully has no moment here.
  final DateTime? lastSeenAtUtc;

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
      'SELECT id, device_name, created_at_utc, last_seen_at_utc, '
      'revoked_at_utc FROM devices ORDER BY created_at_utc ASC',
    );
    return rows.map(_deviceOf).toList(growable: false);
  }

  /// Finds the active device whose stored token hash matches
  /// [presentedTokenHashHex] in constant time, or `null`.
  PairedDevice? findActiveByTokenHash(String presentedTokenHashHex) {
    final db = _library.database;
    final rows = db.select(
      'SELECT id, device_name, created_at_utc, last_seen_at_utc, '
      'revoked_at_utc, token_hash FROM devices',
    );
    for (final row in rows) {
      if (row['revoked_at_utc'] != null) {
        continue;
      }
      final storedHash = row['token_hash']! as String;
      if (!constantTimeHexDigestEquals(presentedTokenHashHex, storedHash)) {
        continue;
      }
      return _deviceOf(row);
    }
    return null;
  }

  /// Records that [deviceId] just authenticated.
  ///
  /// One indexed single-row `UPDATE`, cheap enough to run on every
  /// authenticated call, which is the only place the moment can be observed.
  void markSeen(String deviceId, {DateTime? nowUtc}) {
    final db = _library.database;
    final now = (nowUtc ?? DateTime.now()).toUtc().toIso8601String();
    // Deliberately outside a transaction and without touching
    // updated_at_utc: last-seen is telemetry about access, not a change to
    // what the device is, and it must not make every call a write barrier.
    db.execute(
      'UPDATE devices SET last_seen_at_utc = ? WHERE id = ?',
      <Object?>[now, deviceId],
    );
  }

  /// Revokes the active device matching [presentedTokenHashHex].
  ///
  /// Returns whether a matching active device was found and revoked.
  bool revokeByTokenHash(String presentedTokenHashHex) {
    final target = findActiveByTokenHash(presentedTokenHashHex);
    if (target == null) {
      return false;
    }
    return revokeById(target.id);
  }

  /// Revokes the active device stored under [deviceId].
  ///
  /// Returns whether an active device under that id existed. The token row is
  /// kept but marked revoked, so the device's next call fails authentication
  /// and the PC still remembers that the device once existed.
  bool revokeById(String deviceId) {
    final db = _library.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return runInDatabaseTransaction(db, () {
      final rows = db.select(
        'SELECT revoked_at_utc FROM devices WHERE id = ?',
        <Object?>[deviceId],
      );
      if (rows.isEmpty || rows.first['revoked_at_utc'] != null) {
        return false;
      }
      db.execute(
        'UPDATE devices SET revoked_at_utc = ?, updated_at_utc = ? WHERE id = ?',
        <Object?>[now, now, deviceId],
      );
      return true;
    });
  }

  PairedDevice _deviceOf(Row row) {
    return PairedDevice(
      id: row['id']! as String,
      name: row['device_name']! as String,
      createdAtUtc: DateTime.parse(row['created_at_utc']! as String),
      lastSeenAtUtc: _moment(row['last_seen_at_utc']),
      revokedAtUtc: _moment(row['revoked_at_utc']),
    );
  }

  DateTime? _moment(Object? stored) {
    return stored == null ? null : DateTime.parse(stored as String);
  }
}
