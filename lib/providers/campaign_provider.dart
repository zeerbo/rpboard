import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campaign.dart';
import '../models/chapter.dart';
import '../models/session_screen.dart';
import '../models/component.dart';
import '../core/database/db.dart';
import '../core/ordering/reorder.dart' as ordering;

// ─── Campaigns ───────────────────────────────────────────────────────────────

class CampaignListNotifier extends AsyncNotifier<List<Campaign>> {
  @override
  Future<List<Campaign>> build() => ref.read(databaseProvider).getCampaigns();

  Future<void> add(Campaign c) async {
    await ref.read(databaseProvider).insertCampaign(c);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(databaseProvider).deleteCampaign(id);
    ref.invalidateSelf();
  }
}

final campaignListProvider =
    AsyncNotifierProvider<CampaignListNotifier, List<Campaign>>(
  CampaignListNotifier.new,
);

/// Single-item Campaign provider, keyed by id. The one writer for updates to
/// an existing Campaign — [save] owns invalidating both itself and
/// [campaignListProvider] so the two can never drift apart. See ADR-0004.
class CampaignNotifier extends FamilyAsyncNotifier<Campaign?, String> {
  @override
  Future<Campaign?> build(String id) =>
      ref.read(databaseProvider).getCampaign(id);

  Future<void> save(Campaign c) async {
    await ref.read(databaseProvider).updateCampaign(c);
    ref.invalidateSelf();
    ref.invalidate(campaignListProvider);
  }
}

final campaignProvider =
    AsyncNotifierProvider.family<CampaignNotifier, Campaign?, String>(
  CampaignNotifier.new,
);

// ─── Chapters ────────────────────────────────────────────────────────────────

class ChapterListNotifier extends FamilyAsyncNotifier<List<Chapter>, String> {
  @override
  Future<List<Chapter>> build(String campaignId) =>
      ref.read(databaseProvider).getChapters(campaignId);

  Future<void> add(Chapter c) async {
    await ref.read(databaseProvider).insertChapter(c);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(databaseProvider).deleteChapter(id);
    ref.invalidateSelf();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = await future;
    final reordered = ordering.reorder<Chapter>(list, oldIndex, newIndex);
    await ref.read(databaseProvider).reorderChapters(reordered);
    ref.invalidateSelf();
  }
}

final chapterListProvider = AsyncNotifierProvider.family<ChapterListNotifier,
    List<Chapter>, String>(
  ChapterListNotifier.new,
);

/// Single-item Chapter provider, keyed by id. The one writer for updates to
/// an existing Chapter — [save] owns invalidating both itself and the parent
/// [chapterListProvider] entry for this chapter's campaign. See ADR-0004.
class ChapterNotifier extends FamilyAsyncNotifier<Chapter?, String> {
  @override
  Future<Chapter?> build(String id) =>
      ref.read(databaseProvider).getChapter(id);

  Future<void> save(Chapter c) async {
    await ref.read(databaseProvider).updateChapter(c);
    ref.invalidateSelf();
    ref.invalidate(chapterListProvider(c.campaignId));
  }
}

final chapterProvider =
    AsyncNotifierProvider.family<ChapterNotifier, Chapter?, String>(
  ChapterNotifier.new,
);

// ─── Session Screens ─────────────────────────────────────────────────────────

class ScreenListNotifier
    extends FamilyAsyncNotifier<List<SessionScreen>, String> {
  @override
  Future<List<SessionScreen>> build(String chapterId) =>
      ref.read(databaseProvider).getScreens(chapterId);

  Future<void> add(SessionScreen s) async {
    await ref.read(databaseProvider).insertScreen(s);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(databaseProvider).deleteScreen(id);
    ref.invalidateSelf();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = await future;
    final reordered = ordering.reorder<SessionScreen>(list, oldIndex, newIndex);
    await ref.read(databaseProvider).reorderScreens(reordered);
    ref.invalidateSelf();
  }
}

final screenListProvider = AsyncNotifierProvider.family<ScreenListNotifier,
    List<SessionScreen>, String>(
  ScreenListNotifier.new,
);

/// Single-item SessionScreen provider, keyed by id. The one writer for
/// updates to an existing SessionScreen — [save] owns invalidating both
/// itself and the parent [screenListProvider] entry for this screen's
/// chapter. See ADR-0004.
class ScreenNotifier extends FamilyAsyncNotifier<SessionScreen?, String> {
  @override
  Future<SessionScreen?> build(String id) =>
      ref.read(databaseProvider).getScreen(id);

  Future<void> save(SessionScreen s) async {
    await ref.read(databaseProvider).updateScreen(s);
    ref.invalidateSelf();
    ref.invalidate(screenListProvider(s.chapterId));
  }
}

final screenProvider =
    AsyncNotifierProvider.family<ScreenNotifier, SessionScreen?, String>(
  ScreenNotifier.new,
);

// ─── Components ──────────────────────────────────────────────────────────────

class ComponentListNotifier
    extends FamilyAsyncNotifier<List<SessionComponent>, String> {
  @override
  Future<List<SessionComponent>> build(String screenId) =>
      ref.read(databaseProvider).getComponents(screenId);

  Future<void> add(SessionComponent c) async {
    await ref.read(databaseProvider).insertComponent(c);
    ref.invalidateSelf();
  }

  Future<void> save(SessionComponent c) async {
    await ref.read(databaseProvider).updateComponent(c);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(databaseProvider).deleteComponent(id);
    ref.invalidateSelf();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = await future;
    final reordered = ordering.reorder<SessionComponent>(list, oldIndex, newIndex);
    await ref.read(databaseProvider).reorderComponents(reordered);
    ref.invalidateSelf();
  }
}

final componentListProvider = AsyncNotifierProvider.family<
    ComponentListNotifier, List<SessionComponent>, String>(
  ComponentListNotifier.new,
);
