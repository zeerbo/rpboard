import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/models/campaign.dart';
import 'package:rpboard/models/chapter.dart';
import 'package:rpboard/models/session_screen.dart';
import 'package:rpboard/models/component.dart';

/// A behavioral [Database] fake for provider-level tests. Test-only — lives
/// under `test/`, never `lib/`, so no shipped code can depend on it.
///
/// Backed by per-table maps keyed by id. It reproduces the real
/// [SqfliteDatabase]'s read semantics — ordering (`name ASC` for characters,
/// `updated_at DESC` for campaigns, `order_index ASC` for chapters/screens/
/// components) and foreign-key filtering — so a passing test reflects how
/// production actually reads. If the real adapter's `orderBy`/`where` clauses
/// change, this fake must change with them or tests will pass against a fiction.
///
/// Deliberate divergence: cascade delete is NOT simulated. [SqfliteDatabase]
/// relies on SQLite `ON DELETE CASCADE`; a map-backed fake cannot reproduce it
/// without reimplementing SQLite. Deleting a parent here leaves its children
/// behind. Cascade behavior belongs to a real-adapter/integration test.
///
/// `insert*` upserts (mirrors `ConflictAlgorithm.replace`). `update*` mutates
/// only an existing row (a missing id is a no-op, mirroring SQL `UPDATE`).
/// `delete*` removes the single row by id.
///
/// Reads return freshly-rebuilt instances (`X.fromMap(stored.toMap())`), exactly
/// as [SqfliteDatabase] returns `X.fromMap(row)`. Models are mutable, so handing
/// back the stored object would let a caller silently mutate the backing store —
/// impossible against real SQLite. The round-trip is the defensive copy.
class InMemoryDatabase implements Database {
  final Map<String, Character> _characters = {};
  final Map<String, Campaign> _campaigns = {};
  final Map<String, Chapter> _chapters = {};
  final Map<String, SessionScreen> _screens = {};
  final Map<String, SessionComponent> _components = {};

  // ─── Characters ────────────────────────────────────────────────────────────

  @override
  Future<List<Character>> getCharacters() async {
    final list = _characters.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name)); // name ASC
    return list.map((c) => Character.fromMap(c.toMap())).toList();
  }

  @override
  Future<Character?> getCharacter(String id) async {
    final c = _characters[id];
    return c == null ? null : Character.fromMap(c.toMap());
  }

  @override
  Future<void> insertCharacter(Character c) async => _characters[c.id] = c;

  @override
  Future<void> updateCharacter(Character c) async {
    if (_characters.containsKey(c.id)) _characters[c.id] = c;
  }

  @override
  Future<void> deleteCharacter(String id) async => _characters.remove(id);

  // ─── Campaigns ─────────────────────────────────────────────────────────────

  @override
  Future<List<Campaign>> getCampaigns() async {
    final list = _campaigns.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // updated_at DESC
    return list.map((c) => Campaign.fromMap(c.toMap())).toList();
  }

  @override
  Future<Campaign?> getCampaign(String id) async {
    final c = _campaigns[id];
    return c == null ? null : Campaign.fromMap(c.toMap());
  }

  @override
  Future<void> insertCampaign(Campaign c) async => _campaigns[c.id] = c;

  @override
  Future<void> updateCampaign(Campaign c) async {
    if (_campaigns.containsKey(c.id)) _campaigns[c.id] = c;
  }

  @override
  Future<void> deleteCampaign(String id) async => _campaigns.remove(id);

  // ─── Chapters ──────────────────────────────────────────────────────────────

  @override
  Future<List<Chapter>> getChapters(String campaignId) async {
    final list = _chapters.values
        .where((c) => c.campaignId == campaignId) // FK filter
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order)); // order_index ASC
    return list.map((c) => Chapter.fromMap(c.toMap())).toList();
  }

  @override
  Future<Chapter?> getChapter(String id) async {
    final c = _chapters[id];
    return c == null ? null : Chapter.fromMap(c.toMap());
  }

  @override
  Future<void> insertChapter(Chapter c) async => _chapters[c.id] = c;

  @override
  Future<void> updateChapter(Chapter c) async {
    if (_chapters.containsKey(c.id)) _chapters[c.id] = c;
  }

  @override
  Future<void> deleteChapter(String id) async => _chapters.remove(id);

  /// Applies the whole batch as one indivisible synchronous pass — no
  /// `await` between writes — matching [SqfliteDatabase]'s single-transaction,
  /// all-or-nothing behavior as an observable contract. Only rows whose
  /// `order` actually changed are written.
  @override
  Future<void> reorderChapters(List<Chapter> chapters) async {
    for (final c in chapters) {
      final current = _chapters[c.id];
      if (current != null && current.order == c.order) continue;
      _chapters[c.id] = c;
    }
  }

  // ─── Session Screens ───────────────────────────────────────────────────────

  @override
  Future<List<SessionScreen>> getScreens(String chapterId) async {
    final list = _screens.values
        .where((s) => s.chapterId == chapterId) // FK filter
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order)); // order_index ASC
    return list.map((s) => SessionScreen.fromMap(s.toMap())).toList();
  }

  @override
  Future<SessionScreen?> getScreen(String id) async {
    final s = _screens[id];
    return s == null ? null : SessionScreen.fromMap(s.toMap());
  }

  @override
  Future<void> insertScreen(SessionScreen s) async => _screens[s.id] = s;

  @override
  Future<void> updateScreen(SessionScreen s) async {
    if (_screens.containsKey(s.id)) _screens[s.id] = s;
  }

  @override
  Future<void> deleteScreen(String id) async => _screens.remove(id);

  /// See [reorderChapters] — same indivisible, changed-rows-only contract.
  @override
  Future<void> reorderScreens(List<SessionScreen> screens) async {
    for (final s in screens) {
      final current = _screens[s.id];
      if (current != null && current.order == s.order) continue;
      _screens[s.id] = s;
    }
  }

  // ─── Components ────────────────────────────────────────────────────────────

  @override
  Future<List<SessionComponent>> getComponents(String screenId) async {
    final list = _components.values
        .where((c) => c.screenId == screenId) // FK filter
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order)); // order_index ASC
    return list.map((c) => SessionComponent.fromMap(c.toMap())).toList();
  }

  @override
  Future<void> insertComponent(SessionComponent c) async =>
      _components[c.id] = c;

  @override
  Future<void> updateComponent(SessionComponent c) async {
    if (_components.containsKey(c.id)) _components[c.id] = c;
  }

  @override
  Future<void> deleteComponent(String id) async => _components.remove(id);

  /// See [reorderChapters] — same indivisible, changed-rows-only contract.
  @override
  Future<void> reorderComponents(List<SessionComponent> components) async {
    for (final c in components) {
      final current = _components[c.id];
      if (current != null && current.order == c.order) continue;
      _components[c.id] = c;
    }
  }
}
