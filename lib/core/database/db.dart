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

/// The real SQLite adapter. Lazy-open, ffi init, and path resolution are all
/// private here; sqflite's own [sql.Database] type never leaves this file.
class SqfliteDatabase implements Database {
  sql.Database? _db;

  Future<sql.Database> get _conn async => _db ??= await _open();

  Future<sql.Database> _open() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sql.sqfliteFfiInit();
      sql.databaseFactory = sql.databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'rpboard', 'rpboard.db');
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
}
