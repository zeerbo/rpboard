import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/character.dart';

/// Proves the backup/restore round trip against a real, on-disk
/// `sqflite_common_ffi` database opened the same way the app opens its own
/// (`openAppDatabase`) — the same precedent as the migration execution test
/// (ADR-0005), the foreign-key test (ADR-0006) and the snapshot-import
/// execution test (ADR-0007): some risks can only be verified against a
/// real file, not the in-memory fake.
///
/// This is the test for the PRD's "no app restart needed" requirement:
/// after [restoreDatabaseBackup] overwrites the file, a *fresh* connection
/// opened against the same path — exactly what [SqfliteDatabase.restoreBackup]
/// arranges by closing and dropping its cached connection — sees the
/// restored rows, with nothing about the process itself restarted.
void main() {
  setUpAll(() {
    sql.sqfliteFfiInit();
    sql.databaseFactory = sql.databaseFactoryFfi;
  });

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rpboard-backup-execution-');
    dbPath = p.join(tempDir.path, 'rpboard.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'restoring a backup and reopening the connection shows the restored '
    'state, with nothing about the app restarted',
    () async {
      var db = await openAppDatabase(dbPath);
      await db.insert('characters', Character(id: 'kept', name: 'Kept').toMap());
      await db.close();

      final backup = await backupDatabaseFile(dbPath);

      db = await openAppDatabase(dbPath);
      await db.insert(
        'characters',
        Character(id: 'lost', name: 'Lost to the mistaken import').toMap(),
      );
      await db.close();

      await restoreDatabaseBackup(dbPath, backup.path);

      db = await openAppDatabase(dbPath);
      addTearDown(db.close);
      final rows = await db.query('characters', orderBy: 'id ASC');

      expect(rows.map((r) => r['id']), ['kept']);
    },
  );

  test('a backup taken while the database connection stays open still '
      'captures a valid, readable copy', () async {
    final db = await openAppDatabase(dbPath);
    addTearDown(db.close);
    await db.insert('characters', Character(id: 'a', name: 'Aragorn').toMap());

    final backup = await backupDatabaseFile(dbPath);

    final backupDb = await sql.openDatabase(backup.path, readOnly: true);
    addTearDown(backupDb.close);
    final rows = await backupDb.query('characters');

    expect(rows.map((r) => r['id']), ['a']);
  });
}
