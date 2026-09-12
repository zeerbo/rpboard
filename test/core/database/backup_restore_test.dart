import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rpboard/core/database/db.dart';

/// Realistic-failure and file-shape tests for the backup/restore top-level
/// functions in `db.dart` — [backupDatabaseFile], [listDatabaseBackups] and
/// [restoreDatabaseBackup] — against a real, disposable temporary
/// directory. Mirrors `test/core/sync/folder_sync_transport_test.dart`'s
/// style: these three functions take a plain file path, exactly like
/// [openAppDatabase] does, so none of this needs `path_provider` or a real
/// SQLite connection at all — a backup is a byte-for-byte file copy (PRD
/// "Backups are byte copies of the database file"), so a plain text file
/// standing in for a database is enough to prove the contract.
void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rpboard-backup-test-');
    dbPath = p.join(tempDir.path, 'rpboard.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> writeDb(String contents) => File(dbPath).writeAsString(contents);

  test('a backup contains the pre-import bytes exactly', () async {
    await writeDb('state before the import');

    final info = await backupDatabaseFile(dbPath);

    expect(await File(info.path).readAsString(), 'state before the import');
  });

  test('backups are kept in their own folder next to the database', () async {
    await writeDb('x');

    final info = await backupDatabaseFile(dbPath);

    expect(p.dirname(info.path), p.join(tempDir.path, 'backups'));
  });

  test('backups are named with an ISO-8601 timestamp', () async {
    await writeDb('x');

    final info = await backupDatabaseFile(dbPath, at: DateTime.utc(2026, 3, 4, 5, 6, 7));

    expect(p.basename(info.path), 'rpboard-backup-2026-03-04T05-06-07.000Z.db');
  });

  test('listDatabaseBackups on a fresh database with no backups yet returns '
      'empty rather than throwing', () async {
    await writeDb('x');

    expect(await listDatabaseBackups(dbPath), isEmpty);
  });

  test('backups are listed most recently taken first', () async {
    await writeDb('x');

    final oldest = await backupDatabaseFile(dbPath, at: DateTime.utc(2026, 1, 1));
    final newest = await backupDatabaseFile(dbPath, at: DateTime.utc(2026, 6, 1));
    final middle = await backupDatabaseFile(dbPath, at: DateTime.utc(2026, 3, 1));

    final list = await listDatabaseBackups(dbPath);

    expect(list.map((b) => b.path), [newest.path, middle.path, oldest.path]);
  });

  test('retention keeps the 5 most recent backups and drops the oldest',
      () async {
    await writeDb('x');

    final infos = <DatabaseBackupInfo>[];
    for (var day = 1; day <= 6; day++) {
      infos.add(await backupDatabaseFile(dbPath, at: DateTime.utc(2026, 1, day)));
    }

    final remaining = await listDatabaseBackups(dbPath);

    expect(remaining, hasLength(5));
    expect(remaining.map((b) => b.path), isNot(contains(infos.first.path)),
        reason: 'the oldest of the 6 backups must be the one dropped');
    expect(remaining.map((b) => b.path), containsAll(infos.skip(1).map((b) => b.path)));
  });

  test('two backups taken in the same instant never collide on file name',
      () async {
    await writeDb('x');
    final at = DateTime.utc(2026, 1, 1);

    final first = await backupDatabaseFile(dbPath, at: at);
    final second = await backupDatabaseFile(dbPath, at: at);

    expect(first.path, isNot(second.path));
    expect(await File(first.path).exists(), isTrue);
    expect(await File(second.path).exists(), isTrue);
  });

  test('restore puts back the exact pre-mutation bytes', () async {
    final originalBytes = utf8.encode('state before the mistaken import');
    await File(dbPath).writeAsBytes(originalBytes);

    final info = await backupDatabaseFile(dbPath);
    await File(dbPath).writeAsBytes(utf8.encode('state after a bad import'));

    await restoreDatabaseBackup(dbPath, info.path);

    expect(await File(dbPath).readAsBytes(), originalBytes);
  });

  test('backupDatabaseFile throws when the backups folder cannot be '
      'created, and the database file is left untouched', () async {
    await writeDb('untouched');
    // Put a plain file where the backups *directory* needs to go, so
    // `Directory(...).create()` fails instead of silently succeeding.
    await File(p.join(tempDir.path, 'backups')).writeAsString('not a folder');

    await expectLater(backupDatabaseFile(dbPath), throwsA(anything));

    expect(await File(dbPath).readAsString(), 'untouched');
  });
}
