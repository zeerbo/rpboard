import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import '../../models/character.dart';
import '../../models/campaign.dart';
import '../../models/chapter.dart';
import '../../models/session_screen.dart';
import '../../models/component.dart';
import '../../models/app_snapshot.dart';
import '../ordering/ordered.dart';
import 'migrations.dart';

/// The persistence seam: CRUD over the app's aggregates. Callers reach it
/// through [databaseProvider], never a static global. Lifecycle (open/close)
/// is intentionally absent — it stays private inside the adapter.
abstract interface class Database {
  // ─── Characters ────────────────────────────────────────────────────────────
  Future<List<Character>> getCharacters();
  Future<Character?> getCharacter(String id);
  Future<void> insertCharacter(Character c);
  Future<void> updateCharacter(Character c);
  Future<void> deleteCharacter(String id);

  // ─── Campaigns ─────────────────────────────────────────────────────────────
  Future<List<Campaign>> getCampaigns();
  Future<Campaign?> getCampaign(String id);
  Future<void> insertCampaign(Campaign c);
  Future<void> updateCampaign(Campaign c);
  Future<void> deleteCampaign(String id);

  // ─── Chapters ──────────────────────────────────────────────────────────────
  Future<List<Chapter>> getChapters(String campaignId);
  Future<Chapter?> getChapter(String id);
  Future<void> insertChapter(Chapter c);
  Future<void> updateChapter(Chapter c);
  Future<void> deleteChapter(String id);

  /// Writes the already-reindexed [chapters] list atomically: all changed
  /// rows land together, or none do. Rows whose `order` is unchanged from
  /// what's persisted are not written. See ADR-0003.
  Future<void> reorderChapters(List<Chapter> chapters);

  // ─── Session Screens ───────────────────────────────────────────────────────
  Future<List<SessionScreen>> getScreens(String chapterId);
  Future<SessionScreen?> getScreen(String id);
  Future<void> insertScreen(SessionScreen s);
  Future<void> updateScreen(SessionScreen s);
  Future<void> deleteScreen(String id);

  /// See [reorderChapters] — same atomic, changed-rows-only contract.
  Future<void> reorderScreens(List<SessionScreen> screens);

  // ─── Components ────────────────────────────────────────────────────────────
  Future<List<SessionComponent>> getComponents(String screenId);
  Future<void> insertComponent(SessionComponent c);
  Future<void> updateComponent(SessionComponent c);
  Future<void> deleteComponent(String id);

  /// See [reorderChapters] — same atomic, changed-rows-only contract.
  Future<void> reorderComponents(List<SessionComponent> components);

  // ─── Data transfer (AppSnapshot) ────────────────────────────────────────────
  //
  // See the data-transfer PRD and ADR-0007. [AppSnapshot] covers every
  // Character and every Campaign with its owned Chapters, SessionScreens and
  // SessionComponents.

  /// Reads the complete application state as a point-in-time [AppSnapshot].
  /// Campaign material is reached only by descending from a Campaign
  /// (Campaign → Chapter → SessionScreen → SessionComponent), so a row
  /// orphaned by the foreign-key enforcement defect (ADR-0006) is never
  /// exported — expected, see [AppSnapshot]'s doc comment.
  Future<AppSnapshot> exportSnapshot();

  /// Replaces every aggregate [AppSnapshot] carries with [snapshot]'s
  /// content, atomically: every table it owns is deleted explicitly and then
  /// repopulated, inside one transaction, never relying on `ON DELETE
  /// CASCADE`. Replace semantics, not upsert — nothing of the previous
  /// content survives an import, including any Campaign-material orphan rows
  /// [exportSnapshot] never carried over.
  Future<void> importSnapshot(AppSnapshot snapshot);

  // ─── Backup & restore (safety net around import) ────────────────────────────
  //
  // See the data-transfer PRD ("Backups are byte copies of the database
  // file") and ticket 04. Reading the database file's own location stays
  // inside the adapter by design (ADR-0002), so these three capabilities —
  // taking a backup, pruning old ones, and restoring one — sit at the same
  // level as the database itself rather than above it: a caller never sees
  // a path, only a [DatabaseBackupInfo].

  /// Copies the current database file, byte for byte — not a logical
  /// export — into a `backups/` folder next to it, named with an ISO-8601
  /// timestamp, then removes any backup beyond the 5 most recent. A byte
  /// copy is deliberate: the backup's whole purpose is to cover the case
  /// where the logical export (`AppSnapshot`/`SnapshotCodec`) lost
  /// something, so it must not share that mechanism.
  Future<DatabaseBackupInfo> backupDatabase();

  /// Every backup this adapter can see, most recent first.
  Future<List<DatabaseBackupInfo>> listBackups();

  /// Overwrites the live database file with [backup]'s bytes, byte for
  /// byte, then reopens the connection so the restored state is visible on
  /// the very next read — no app restart required. An explicit user action
  /// only: never called automatically on an import failure, since a
  /// rollback triggered by a misread error can destroy more than it saves.
  ///
  /// Restoring a backup taken under an older schema simply reopens an
  /// older schema, which the migration ladder already carries forward on
  /// open (ADR-0005): a restore is therefore never a downgrade.
  Future<void> restoreBackup(DatabaseBackupInfo backup);
}

/// One backup of the database file: a byte-for-byte copy kept in a
/// `backups/` folder next to the database, named with an ISO-8601
/// timestamp. See [Database.backupDatabase].
class DatabaseBackupInfo {
  final String path;
  final DateTime createdAt;

  const DatabaseBackupInfo({required this.path, required this.createdAt});
}

/// The published seam. Default builds the real on-device SQLite store; tests
/// override it with an in-memory fake.
final databaseProvider = Provider<Database>((ref) => SqfliteDatabase());

/// Opens an RPBoard database at [path] with the app's own connection
/// configuration and schema wiring: the [productionLadder] drives both the
/// fresh-install and the carry-forward hook, so a freshly created database and
/// a migrated one are always built by the identical code path (ADR-0005).
///
/// [SqfliteDatabase._open] resolves the on-device path, then calls this. Only
/// the path varies, which is the point: a test can open a throwaway database
/// configured *exactly* the way the app configures its real one, down to the
/// ladder. A test that re-listed these options itself would prove nothing about
/// how the app behaves — only about how the test builds its options, which is
/// how ADR-0006's defect went unnoticed for the whole life of the schema.
Future<sql.Database> openAppDatabase(String path) {
  const migrations = Migrations();
  return sql.openDatabase(
    path,
    version: migrations.latestVersion,
    onConfigure: _enforceForeignKeys,
    onCreate: (db, version) => migrations.apply(db, 0, version),
    onUpgrade: (db, oldVersion, newVersion) =>
        migrations.apply(db, oldVersion, newVersion),
  );
}

/// Turns on the foreign key enforcement the schema's `ON DELETE CASCADE`
/// clauses have always assumed. SQLite leaves it off by default and the
/// setting is per *connection*, not stored in the file, so this has to run on
/// every open — which is why it lives here and not in a [Migrations] step, a
/// step being a one-off at a version change. `sqflite` invokes `onConfigure`
/// first among the open hooks and outside the version-change transaction,
/// where a pragma can still take effect. See ADR-0006.
Future<void> _enforceForeignKeys(sql.Database db) =>
    db.execute('PRAGMA foreign_keys = ON');

/// Reads the complete application state from [db] as an [AppSnapshot]. A
/// connection-level counterpart to [SqfliteDatabase.exportSnapshot], pulled
/// out to a top-level function — like [openAppDatabase] — so a test can
/// exercise it against a real ffi connection without going through
/// [SqfliteDatabase]'s `path_provider`-based path resolution, which has no
/// implementation in a `flutter test` process (ADR-0006).
///
/// Campaign material is read by descending from each Campaign — its
/// Chapters, each Chapter's SessionScreens, each SessionScreen's
/// SessionComponents — rather than a flat `SELECT * FROM chapters` and so
/// on. This is deliberate, not incidental: a row orphaned by the
/// foreign-key-enforcement defect (ADR-0006) has no reachable parent, so
/// descending from Campaign naturally excludes it. See [AppSnapshot]'s doc
/// comment on this known, expected effect.
Future<AppSnapshot> exportSnapshotFrom(sql.Database db) async {
  final characterRows = await db.query('characters', orderBy: 'name ASC');
  final characters = characterRows.map(Character.fromMap).toList();

  final campaignRows = await db.query('campaigns', orderBy: 'updated_at DESC');
  final campaigns = campaignRows.map(Campaign.fromMap).toList();

  final chapters = <Chapter>[];
  final screens = <SessionScreen>[];
  final components = <SessionComponent>[];

  for (final campaign in campaigns) {
    final chapterRows = await db.query(
      'chapters',
      where: 'campaign_id = ?',
      whereArgs: [campaign.id],
      orderBy: 'order_index ASC',
    );
    final campaignChapters = chapterRows.map(Chapter.fromMap).toList();
    chapters.addAll(campaignChapters);

    for (final chapter in campaignChapters) {
      final screenRows = await db.query(
        'session_screens',
        where: 'chapter_id = ?',
        whereArgs: [chapter.id],
        orderBy: 'order_index ASC',
      );
      final chapterScreens = screenRows.map(SessionScreen.fromMap).toList();
      screens.addAll(chapterScreens);

      for (final screen in chapterScreens) {
        final componentRows = await db.query(
          'components',
          where: 'screen_id = ?',
          whereArgs: [screen.id],
          orderBy: 'order_index ASC',
        );
        components.addAll(componentRows.map(SessionComponent.fromMap));
      }
    }
  }

  return AppSnapshot(
    characters: characters,
    campaigns: campaigns,
    chapters: chapters,
    screens: screens,
    components: components,
  );
}

/// Replaces every table [AppSnapshot] carries — `characters`, `campaigns`,
/// `chapters`, `session_screens`, `components` — with [snapshot]'s content,
/// inside one transaction. Deletes are explicit and never rely on `ON DELETE
/// CASCADE` (see the data-transfer PRD's "Orphan rows" note): a failure
/// partway through must leave [db] exactly as it was before this call, which
/// is asserted against a real ffi connection in
/// `test/core/database/snapshot_import_execution_test.dart` — the suite's
/// third documented exception to the pure-test rule, after the migration
/// execution test (ADR-0005) and the foreign-key test (ADR-0006). The
/// in-memory fake has no transaction, so it cannot prove a rollback;
/// atomicity is the entire justification for a destructive import, so it is
/// asserted where it actually lives.
///
/// Deletes run leaf-to-root (components, then session_screens, then
/// chapters, then campaigns, then characters) and inserts run root-to-leaf
/// (characters and campaigns, then chapters, then screens, then components),
/// so a parent row always exists before a child row referencing it is
/// inserted — required now that foreign keys are enforced (ADR-0006).
Future<void> importSnapshotInto(sql.Database db, AppSnapshot snapshot) async {
  await db.transaction((txn) async {
    await txn.delete('components');
    await txn.delete('session_screens');
    await txn.delete('chapters');
    await txn.delete('campaigns');
    await txn.delete('characters');

    for (final character in snapshot.characters) {
      await txn.insert('characters', character.toMap());
    }
    for (final campaign in snapshot.campaigns) {
      await txn.insert('campaigns', campaign.toMap());
    }
    for (final chapter in snapshot.chapters) {
      await txn.insert('chapters', chapter.toMap());
    }
    for (final screen in snapshot.screens) {
      await txn.insert('session_screens', screen.toMap());
    }
    for (final component in snapshot.components) {
      await txn.insert('components', component.toMap());
    }
  });
}

/// Only the 5 most recent backups are kept (PRD, ticket 04).
const _maxBackups = 5;

/// The fixed prefix every backup file name carries, and the counterpart to
/// [_parseBackupTimestamp] below.
const _backupFilePrefix = 'rpboard-backup-';

/// Filesystem-safe stand-in for a raw ISO-8601 string: Windows (the
/// collaudo target) refuses `:` in a file name. Mirrors
/// `FolderSyncTransport._sanitizedTimestamp`.
String _sanitizedBackupTimestamp(DateTime t) =>
    t.toUtc().toIso8601String().replaceAll(':', '-');

/// The inverse of [_sanitizedBackupTimestamp], read back out of a backup
/// file's name so [listDatabaseBackups] can report when a backup was taken
/// without depending on filesystem metadata. Tolerant of the numeric
/// `-<n>` suffix [backupDatabaseFile] appends to avoid a same-millisecond
/// collision: the pattern only anchors the start of the name.
final _backupNamePattern =
    RegExp(r'^rpboard-backup-(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})(\.\d+)?Z');

DateTime? _parseBackupTimestamp(String fileName) {
  final base = p.basenameWithoutExtension(fileName);
  final match = _backupNamePattern.firstMatch(base);
  if (match == null) return null;
  final fraction = match.group(5) ?? '';
  return DateTime.tryParse(
      '${match.group(1)}T${match.group(2)}:${match.group(3)}:${match.group(4)}$fraction' 'Z');
}

Future<DateTime> _backupCreatedAt(File file) async =>
    _parseBackupTimestamp(file.path) ?? await file.lastModified();

/// The `backups/` folder next to the database at [dbPath] — a sibling of
/// the database file, exactly like `FolderSyncTransport`'s `transfer/`
/// folder is a sibling of the database (PRD "Backups... kept in their own
/// folder next to the database").
Directory _backupsFolder(String dbPath) =>
    Directory(p.join(p.dirname(dbPath), 'backups'));

/// Copies the database file at [dbPath], byte for byte, into its
/// `backups/` folder, named `rpboard-backup-<ISO8601>.db`, then prunes
/// anything beyond the [_maxBackups] most recent. A plain [File.copy] — not
/// a logical export — deliberately, per the PRD.
///
/// Pulled out to a top-level function — like [openAppDatabase] and
/// [importSnapshotInto] — so a test can exercise it against a real
/// temporary directory with no [SqfliteDatabase] and no `path_provider`
/// involved at all. [at] lets a test fix the backup's timestamp instead of
/// depending on wall-clock ordering between successive calls; production
/// never passes it, so it defaults to the real current time.
Future<DatabaseBackupInfo> backupDatabaseFile(String dbPath, {DateTime? at}) async {
  final now = at ?? DateTime.now();
  final backupsDir = _backupsFolder(dbPath);
  await backupsDir.create(recursive: true);

  final base = '$_backupFilePrefix${_sanitizedBackupTimestamp(now)}';
  var backupFile = File(p.join(backupsDir.path, '$base.db'));
  var suffix = 1;
  while (await backupFile.exists()) {
    backupFile = File(p.join(backupsDir.path, '$base-$suffix.db'));
    suffix++;
  }
  await File(dbPath).copy(backupFile.path);

  await _pruneOldBackups(backupsDir);

  return DatabaseBackupInfo(path: backupFile.path, createdAt: now);
}

/// Deletes every backup in [backupsDir] beyond the [_maxBackups] most
/// recent, oldest first.
Future<void> _pruneOldBackups(Directory backupsDir) async {
  final files = await backupsDir
      .list()
      .where((e) => e is File && p.extension(e.path) == '.db')
      .cast<File>()
      .toList();
  if (files.length <= _maxBackups) return;

  final withTimes = await Future.wait(
      files.map((f) async => MapEntry(f, await _backupCreatedAt(f))));
  withTimes.sort((a, b) => a.value.compareTo(b.value));

  for (final entry in withTimes.take(withTimes.length - _maxBackups)) {
    await entry.key.delete();
  }
}

/// Every backup next to the database at [dbPath], most recent first.
/// Returns empty when the `backups/` folder doesn't exist yet — a fresh
/// install that has never imported anything.
Future<List<DatabaseBackupInfo>> listDatabaseBackups(String dbPath) async {
  final backupsDir = _backupsFolder(dbPath);
  if (!await backupsDir.exists()) return [];

  final infos = <DatabaseBackupInfo>[];
  await for (final entity in backupsDir.list()) {
    if (entity is! File || p.extension(entity.path) != '.db') continue;
    infos.add(DatabaseBackupInfo(
        path: entity.path, createdAt: await _backupCreatedAt(entity)));
  }
  infos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return infos;
}

/// Overwrites the database file at [dbPath] with [backupPath]'s bytes, byte
/// for byte — the inverse of [backupDatabaseFile]. Plain [File.copy]:
/// restoring is a filesystem operation, not a logical import, so it never
/// goes through [importSnapshotInto] or touches `AppSnapshot` at all.
Future<void> restoreDatabaseBackup(String dbPath, String backupPath) =>
    File(backupPath).copy(dbPath).then((_) {});

/// The real SQLite adapter. Lazy-open, ffi init, and path resolution are all
/// private here; sqflite's own [sql.Database] type never leaves this file.
class SqfliteDatabase implements Database {
  sql.Database? _db;

  Future<sql.Database> get _conn async => _db ??= await _open();

  /// Where this installation's database file lives. Resolved through
  /// `path_provider`, so it stays a `Future`-returning method rather than a
  /// cached field — mirrors [_open] itself, which already re-derives this
  /// same path on every fresh open.
  Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'rpboard', 'rpboard.db');
  }

  Future<sql.Database> _open() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sql.sqfliteFfiInit();
      sql.databaseFactory = sql.databaseFactoryFfi;
    }

    final path = await _dbPath();
    await Directory(p.dirname(path)).create(recursive: true);

    return openAppDatabase(path);
  }

  // ─── Characters ────────────────────────────────────────────────────────────

  @override
  Future<List<Character>> getCharacters() async {
    final d = await _conn;
    final rows = await d.query('characters', orderBy: 'name ASC');
    return rows.map(Character.fromMap).toList();
  }

  @override
  Future<Character?> getCharacter(String id) async {
    final d = await _conn;
    final rows = await d.query('characters', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Character.fromMap(rows.first);
  }

  @override
  Future<void> insertCharacter(Character c) async {
    final d = await _conn;
    await d.insert('characters', c.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateCharacter(Character c) async {
    final d = await _conn;
    await d.update('characters', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  @override
  Future<void> deleteCharacter(String id) async {
    final d = await _conn;
    await d.delete('characters', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Campaigns ─────────────────────────────────────────────────────────────

  @override
  Future<List<Campaign>> getCampaigns() async {
    final d = await _conn;
    final rows = await d.query('campaigns', orderBy: 'updated_at DESC');
    return rows.map(Campaign.fromMap).toList();
  }

  @override
  Future<Campaign?> getCampaign(String id) async {
    final d = await _conn;
    final rows = await d.query('campaigns', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Campaign.fromMap(rows.first);
  }

  /// No `ConflictAlgorithm.replace` here, unlike the two leaf tables. With
  /// foreign keys enforced (ADR-0006), `INSERT OR REPLACE` on a parent row
  /// *deletes* the existing row before inserting, and that delete cascades:
  /// re-inserting an existing id would silently take its whole subtree with
  /// it. Verified, and characterized by a test. Letting a duplicate id throw
  /// is the far better failure — no caller does it today, since every `add`
  /// mints a fresh uuid and every edit goes through `update`.
  @override
  Future<void> insertCampaign(Campaign c) async {
    final d = await _conn;
    await d.insert('campaigns', c.toMap());
  }

  @override
  Future<void> updateCampaign(Campaign c) async {
    final d = await _conn;
    await d.update('campaigns', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  @override
  Future<void> deleteCampaign(String id) async {
    final d = await _conn;
    await d.delete('campaigns', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<Chapter>> getChapters(String campaignId) async {
    final d = await _conn;
    final rows = await d.query('chapters',
        where: 'campaign_id = ?',
        whereArgs: [campaignId],
        orderBy: 'order_index ASC');
    return rows.map(Chapter.fromMap).toList();
  }

  @override
  Future<Chapter?> getChapter(String id) async {
    final d = await _conn;
    final rows = await d.query('chapters', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Chapter.fromMap(rows.first);
  }

  /// See [insertCampaign] on why this one does not replace on conflict.
  @override
  Future<void> insertChapter(Chapter c) async {
    final d = await _conn;
    await d.insert('chapters', c.toMap());
  }

  @override
  Future<void> updateChapter(Chapter c) async {
    final d = await _conn;
    await d.update('chapters', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  @override
  Future<void> deleteChapter(String id) async {
    final d = await _conn;
    await d.delete('chapters', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> reorderChapters(List<Chapter> chapters) =>
      _reorderRows('chapters', chapters, (c) => c.toMap());

  /// One transaction per reorder batch, writing only the rows whose
  /// `order_index` actually changed. The public entry points stay typed per
  /// aggregate (so a wrong-id list is a compile error, per ADR-0003); this
  /// private helper carries the single shared body.
  Future<void> _reorderRows<T extends Ordered<T>>(
    String table,
    List<T> items,
    Map<String, dynamic> Function(T) toMap,
  ) async {
    final d = await _conn;
    await d.transaction((txn) async {
      for (final item in items) {
        final rows = await txn.query(table,
            columns: ['order_index'], where: 'id = ?', whereArgs: [item.id]);
        final persistedOrder =
            rows.isEmpty ? null : rows.first['order_index'] as int?;
        if (persistedOrder == item.order) continue;
        await txn
            .update(table, toMap(item), where: 'id = ?', whereArgs: [item.id]);
      }
    });
  }

  // ─── Session Screens ───────────────────────────────────────────────────────

  @override
  Future<List<SessionScreen>> getScreens(String chapterId) async {
    final d = await _conn;
    final rows = await d.query('session_screens',
        where: 'chapter_id = ?',
        whereArgs: [chapterId],
        orderBy: 'order_index ASC');
    return rows.map(SessionScreen.fromMap).toList();
  }

  @override
  Future<SessionScreen?> getScreen(String id) async {
    final d = await _conn;
    final rows =
        await d.query('session_screens', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SessionScreen.fromMap(rows.first);
  }

  /// See [insertCampaign] on why this one does not replace on conflict.
  @override
  Future<void> insertScreen(SessionScreen s) async {
    final d = await _conn;
    await d.insert('session_screens', s.toMap());
  }

  @override
  Future<void> updateScreen(SessionScreen s) async {
    final d = await _conn;
    await d.update('session_screens', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  @override
  Future<void> deleteScreen(String id) async {
    final d = await _conn;
    await d.delete('session_screens', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> reorderScreens(List<SessionScreen> screens) =>
      _reorderRows('session_screens', screens, (s) => s.toMap());

  // ─── Components ────────────────────────────────────────────────────────────

  @override
  Future<List<SessionComponent>> getComponents(String screenId) async {
    final d = await _conn;
    final rows = await d.query('components',
        where: 'screen_id = ?',
        whereArgs: [screenId],
        orderBy: 'order_index ASC');
    return rows.map(SessionComponent.fromMap).toList();
  }

  @override
  Future<void> insertComponent(SessionComponent c) async {
    final d = await _conn;
    await d.insert('components', c.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateComponent(SessionComponent c) async {
    final d = await _conn;
    await d.update('components', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  @override
  Future<void> deleteComponent(String id) async {
    final d = await _conn;
    await d.delete('components', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> reorderComponents(List<SessionComponent> components) =>
      _reorderRows('components', components, (c) => c.toMap());

  // ─── Data transfer (AppSnapshot) ────────────────────────────────────────────

  @override
  Future<AppSnapshot> exportSnapshot() async {
    final d = await _conn;
    return exportSnapshotFrom(d);
  }

  @override
  Future<void> importSnapshot(AppSnapshot snapshot) async {
    final d = await _conn;
    await importSnapshotInto(d, snapshot);
  }

  // ─── Backup & restore ──────────────────────────────────────────────────────

  @override
  Future<DatabaseBackupInfo> backupDatabase() async {
    await _conn; // ensures the database file actually exists on disk
    final path = await _dbPath();
    return backupDatabaseFile(path);
  }

  @override
  Future<List<DatabaseBackupInfo>> listBackups() async {
    final path = await _dbPath();
    return listDatabaseBackups(path);
  }

  @override
  Future<void> restoreBackup(DatabaseBackupInfo backup) async {
    final path = await _dbPath();
    // The live connection holds the database file open; it must be closed
    // before the file underneath it can be overwritten. The next caller to
    // touch this adapter re-opens it lazily through [_conn], now against
    // the restored bytes — which is what makes the restored state visible
    // without the user restarting the app.
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    await restoreDatabaseBackup(path, backup.path);
  }
}
