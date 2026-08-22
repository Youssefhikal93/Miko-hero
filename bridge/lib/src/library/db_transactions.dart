import 'package:sqlite3/sqlite3.dart';

/// Runs [work] inside a single SQLite transaction.
///
/// Opens with `BEGIN IMMEDIATE` (so write locks are taken up front instead
/// of failing mid-transaction), commits on success, and rolls back on any
/// thrown error before rethrowing it. Rollback failures are swallowed so
/// they never mask the original error.
T runInDatabaseTransaction<T>(Database db, T Function() work) {
  db.execute('BEGIN IMMEDIATE');
  try {
    final T result = work();
    db.execute('COMMIT');
    return result;
  } catch (_) {
    try {
      db.execute('ROLLBACK');
    } catch (_) {
      // The original error must win over a failed rollback.
    }
    rethrow;
  }
}
