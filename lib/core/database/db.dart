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
}

/// The published seam. Default builds the real on-device SQLite store; tests
/// override it with an in-memory fake.
final databaseProvider = Provider<Database>((ref) => SqfliteDatabase());

/// The real SQLite adapter. Lazy-open, ffi init, and path resolution are all
/// private here; sqflite's own [sql.Database] type never leaves this file.
class SqfliteDatabase implements Database {
  sql.Database? _db;

  /// Selects and applies schema steps for both a fresh install ([_onCreate])
  /// and an existing one being carried forward ([_onUpgrade]). Both hooks
  /// below are thin callers of the same ladder, so a freshly created
  /// database and a migrated one can never quietly drift apart.
  final Migrations _migrations = const Migrations();

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

    return sql.openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// A fresh database: apply every step from scratch.
  Future<void> _onCreate(sql.Database db, int version) =>
      _migrations.apply(db, 0, version);

  /// An existing database being carried forward: apply every step above
  /// whatever version is already on disk.
  Future<void> _onUpgrade(sql.Database db, int oldVersion, int newVersion) =>
      _migrations.apply(db, oldVersion, newVersion);

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

  @override
  Future<void> insertCampaign(Campaign c) async {
    final d = await _conn;
    await d.insert('campaigns', c.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.replace);
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

  @override
  Future<void> insertChapter(Chapter c) async {
    final d = await _conn;
    await d.insert('chapters', c.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.replace);
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

  @override
  Future<void> insertScreen(SessionScreen s) async {
    final d = await _conn;
    await d.insert('session_screens', s.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.replace);
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
}
