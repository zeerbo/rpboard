import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';

/// The suite's **third** documented exception to the pure-test rule, after
/// the migration execution test (ADR-0005) and the foreign-key test
/// (ADR-0006). See ADR-0007.
///
/// [InMemoryDatabase] applies `importSnapshot` as one indivisible synchronous
/// pass with no `await` between the clear and the inserts, which mirrors the
/// real adapter's all-or-nothing behavior as an observable contract — but it
/// has no actual transaction, so it cannot prove a rollback. Since the whole
/// justification for a destructive, replace-semantics import is that it is
/// atomic, atomicity has to be asserted where it actually lives: a real
/// `sqflite_common_ffi` connection, opened the same way the app opens its
/// own (`openAppDatabase`), with a transaction forced to fail partway
/// through.
void main() {
  setUpAll(() {
    sql.sqfliteFfiInit();
    sql.databaseFactory = sql.databaseFactoryFfi;
  });

  test(
    'an import forced to fail partway leaves the database exactly as it was',
    () async {
      final db = await openAppDatabase(sql.inMemoryDatabasePath);
      addTearDown(db.close);

      final existing = Character(id: 'existing', name: 'Original');
      await db.insert('characters', existing.toMap());

      // Two characters sharing an id: the second insert inside the same
      // transaction violates the primary key constraint, so the whole
      // transaction — including the delete of the pre-existing row and the
      // first, otherwise-successful insert — must roll back together.
      final badSnapshot = AppSnapshot(characters: [
        Character(id: 'new-1', name: 'First of the pair'),
        Character(id: 'new-1', name: 'Collides with the one above'),
      ]);

      await expectLater(
        importSnapshotInto(db, badSnapshot),
        throwsA(isA<sql.DatabaseException>()),
      );

      final rows = await db.query('characters');
      expect(rows, hasLength(1),
          reason: 'no rows deleted, no rows inserted: the failed import must '
              'leave the table exactly as it was before the call');
      expect(rows.single['id'], 'existing');
      expect(rows.single['name'], 'Original');
    },
  );

  test(
    'a succeeding import commits the delete and every insert together',
    () async {
      final db = await openAppDatabase(sql.inMemoryDatabasePath);
      addTearDown(db.close);

      await db.insert('characters', Character(id: 'old', name: 'Gone after import').toMap());

      final snapshot = AppSnapshot(characters: [
        Character(id: 'a', name: 'Aragorn'),
        Character(id: 'b', name: 'Boromir'),
      ]);

      await importSnapshotInto(db, snapshot);

      final rows = await db.query('characters', orderBy: 'id ASC');
      expect(rows.map((r) => r['id']), ['a', 'b']);
    },
  );
}
