Status: ready-for-agent

# A module for ordered reordering

Implements architecture-review candidate **C3** (`docs/architecture-review.html#c3`). A new ADR-0003 records the accepted decision this PRD implements; it builds on [ADR-0002](../../docs/adr/0002-database-seam.md), whose "no transaction primitive added" consequence names this PRD as the place that decision gets revisited, and amends it.

## Problem Statement

Reordering a Chapter list, a SessionScreen list, or a SessionComponent list means the same four steps today, copy-pasted into three different screens (`campaign_screen.dart`, `chapter_screen.dart`, `session_edit_screen.dart`): remove the dragged item from the list, re-insert it at its new position, loop over the whole list writing a new `order` to every row, then invalidate the provider. Two things are wrong with this. First, the loop mutates the very list instance the provider's `AsyncValue` owns — the screen reaches into state it doesn't own and edits it in place before the provider has any say. Second, the write-back is N separate `update` calls with no transaction around them: if the app crashes, loses power, or throws midway through the loop, some rows have their new `order_index` and some still have the old one, and the persisted order is no longer a coherent sequence. A DM who reorders a chapter mid-session and hits a crash can come back to a chapter list that's silently scrambled, with no error ever shown.

## Solution

Extract the reorder logic once, as a small pure function that knows nothing about Flutter, Riverpod, or SQLite: given a list and the two indices `ReorderableListView` reports, it returns a brand-new, densely-reindexed list, touching neither the input list nor its elements. Chapter, SessionScreen, and SessionComponent each declare themselves reorderable through one shared contract, so the function is written once and used three times. On the persistence side, the `Database` seam gains three narrow methods — one per reorderable aggregate — each of which writes its changed rows inside a single transaction, so a crash mid-write leaves the previously-persisted order intact rather than half-updated. The three list notifiers (`ChapterListNotifier`, `ScreenListNotifier`, `ComponentListNotifier`) become the only callers of both pieces: each gets a `reorder(oldIndex, newIndex)` method that reads its own current list, calls the pure function, calls the matching transactional seam method, and invalidates itself — exactly the same shape `add`/`save`/`delete` already have. The three screens shrink to passing two integers; after this change none of them touches the database or a provider-owned list directly.

## User Stories

1. As a DM, I want to drag a chapter into a new position and trust the new order survives a crash immediately afterward, so that a bad-timing app close never leaves my campaign's chapters in a scrambled, inconsistent order.
2. As a DM, I want reordering scenes within a chapter to behave the same way, so that the guarantee isn't specific to one screen.
3. As a DM, I want reordering components on a session screen to behave the same way, so that all three places I can drag-and-drop share the same reliability.
4. As a DM, I want a reorder to either fully apply or not apply at all, so that I never see a list that's part old order, part new order.
5. As a developer, I want the reorder algorithm — index math, list mutation, reindexing — written exactly once, so that a bug found in one place is fixed in all three instead of needing three matching patches.
6. As a developer, I want that algorithm to be pure (no Flutter, no Riverpod, no database), so that I can unit-test it directly against plain Dart objects with no widget pump and no fake database.
7. As a developer, I want the pure function to return a new list and leave its input list and input elements untouched, so that a screen or notifier can never accidentally corrupt state it still holds a reference to.
8. As a developer, I want a shared `Ordered<T>` contract that Chapter, SessionScreen, and SessionComponent all implement, so that the generic reorder function has one uniform shape to work against instead of three near-identical copies.
9. As a developer, I want each reorderable model to produce a new instance with an updated order rather than mutating itself in place, so that "returns a new list of new instances" is true all the way down, not just at the list level.
10. As a developer, I want the `Database` seam to expose one transactional method per reorderable aggregate (`reorderChapters`, `reorderScreens`, `reorderComponents`), so that the transaction boundary lives in the one place that already owns persistence concerns, not scattered across screens.
11. As a developer, I want `SqfliteDatabase` to wrap each of those methods in a single real sqflite transaction, so that the atomicity guarantee is backed by the actual database engine, not simulated.
12. As a developer, I want `InMemoryDatabase` to apply a reorder batch as one indivisible step, so that provider tests can rely on the same all-or-nothing behavior the real adapter provides.
13. As a developer, I want only the rows whose `order` actually changed to be written, so that a reorder that shifts one item by one slot doesn't rewrite every row in the list for no reason.
14. As a developer maintaining `ChapterListNotifier`, `ScreenListNotifier`, and `ComponentListNotifier`, I want each to expose a `reorder(oldIndex, newIndex)` method with the same `add`/`save`/`delete`/`invalidateSelf` shape the rest of the notifier already has, so that reordering isn't a special case in the provider layer.
15. As a developer maintaining the three screens, I want to pass only the two indices `ReorderableListView.onReorder` already hands me, so that the screen no longer needs to know how reordering is implemented, mutate a list, or reach the database at all.
16. As a developer picking up C4 (single-item providers) later, I want reordering to stay a collection-level operation on the list notifier, so that C4's "only the single-item provider writes" rule doesn't have to account for a special case here.
17. As a developer, I want the ordering guarantee stated precisely — after any reorder, persisted `order_index` values are a dense `0..n-1` sequence — so that nothing downstream (rendering order, next-insert position) has to guess or defend against gaps or duplicates.

## Implementation Decisions

- **Three narrow seam methods, not a general transaction primitive.** `Database` gains exactly `reorderChapters(List<Chapter>)`, `reorderScreens(List<SessionScreen>)`, `reorderComponents(List<SessionComponent>)` — one per reorderable aggregate, each taking the already-reindexed list. No generic `transaction(callback)` escape hatch is added to the interface.
- **This supersedes part of ADR-0002.** ADR-0002 explicitly deferred the transaction question with "the shape of an atomic-reorder operation is C3's decision and is not pre-installed speculatively." This PRD is that decision, and ADR-0003 records it as amending ADR-0002 rather than contradicting it.
- **`SqfliteDatabase` wraps each method in one sqflite transaction.** All changed-row writes for a single reorder call happen inside one `db.transaction(...)` block, so a mid-write failure rolls back to the prior persisted order instead of leaving a partial write.
- **`InMemoryDatabase` applies the whole batch as one step.** The fake has no real transaction to lean on, so it applies all changed rows to its in-memory map in a single synchronous pass with no `await` in between, matching the real adapter's all-or-nothing behavior from the caller's point of view.
- **A shared `Ordered<T>` contract.** `abstract interface class Ordered<T>` exposes `String get id`, `int get order`, and `T withOrder(int)`. Chapter, SessionScreen, and SessionComponent each implement it, and each gains a small local `copyWith`-style method to back `withOrder`.
- **Rejected: `set order` on the contract.** A mutating setter would let the reorder function "work" while still mutating instances the provider still holds a reference to elsewhere — purity would be only apparent, not real. `withOrder` returning a new instance is the only shape that keeps the guarantee honest.
- **Rejected: reordering a bare `List<String>` of ids.** Working purely on ids instead of entities would push the id-to-entity lookup and re-hydration into every notifier that wants to reorder, multiplying the exact kind of duplication this module exists to remove.
- **A pure generic function, `reorder<T extends Ordered<T>>(List<T> list, int oldIndex, int newIndex) -> List<T>`.** Lives in its own module under `lib/core/ordering/`. It owns the `ReorderableListView` index-convention adjustment (`if (newIndex > oldIndex) newIndex--`) internally, so no caller repeats that adjustment. It returns a brand-new list of brand-new, densely-reindexed instances; it never mutates the list or instances passed in.
- **Call sites move to the list notifiers.** `ChapterListNotifier`, `ScreenListNotifier`, and `ComponentListNotifier` each gain a `reorder(int oldIndex, int newIndex)` method: read the notifier's current list, call the pure `reorder` function, call the matching transactional seam method, then `invalidateSelf()` — the same shape as the existing `add`/`save`/`delete` methods on each notifier.
- **Screens shrink to passing two indices.** `campaign_screen.dart`, `chapter_screen.dart`, and `session_edit_screen.dart` each replace their local `_reorder`/`_reorderChapters` method with a call to `ref.read(<list>Provider(...).notifier).reorder(oldIndex, newIndex)`. After this change none of the three screens imports `databaseProvider` for reordering purposes or mutates a list it read from a provider.
- **Reordering stays a list-notifier concern.** It is a collection operation — reshuffling which entities exist at which position within a list — not a single-entity write, so it is unaffected by C4's later "only the single-item provider writes" rule.
- **Write only changed rows.** Within the one transaction, each seam method writes only the rows whose `order` actually differs from what's currently persisted, not the entire list unconditionally.
- **Dense ordering guarantee.** After any successful reorder, the persisted `order_index` values for the affected list are exactly `0..n-1` with no gaps or duplicates — the pure function's reindexing step is what makes this true, and the seam methods only ever receive already-dense input.

## Testing Decisions

- **Pure-Dart, no widget pump, no real SQLite** — the same discipline as the existing `test/providers/*_test.dart` files and the prior-art `test/models/component_test.dart`.
- **The pure `reorder` function is tested directly** against a tiny fake `Ordered` implementation, with no Flutter and no database in the picture: move an item down, move an item up, move first to last, move last to first, a no-op reorder (same start and end position), a single-element list, and an empty list. Assertions cover that the returned list is a new list object, that the original input list is untouched, that none of the original input instances are mutated, and that the result's `order` values are densely `0..n-1`.
- **The three notifiers are tested through the existing single seam.** `databaseProvider`, overridden with `InMemoryDatabase` in a `ProviderContainer`, is the only test seam used — no new seam is introduced for this PRD. Tests assert external behavior: after calling `reorder(oldIndex, newIndex)` on a notifier, re-reading through the seam returns the entities in the new order with dense `order_index` values.
- **`InMemoryDatabase` gains the three new methods**, and its batch-apply semantics are written to match the real adapter's transactional behavior as an observable contract (all rows land together), not by simulating rollback internally.
- **What is not asserted:** call counts, private fields, or whether a transaction object was actually opened. The observable contract under test is "the new order is readable after a successful reorder, and the old order stays intact if a reorder does not complete" — not the mechanism used to achieve it.

## Out of Scope

- Reordering Campaigns — Campaign has no `order` field and is listed by `updated_at DESC`; it is not part of this module.
- A general `transaction(callback)` primitive on the `Database` seam — rejected in Implementation Decisions above in favor of three narrow, typed methods.
- Single-item providers (C4) — reordering stays a collection operation on the existing list notifiers regardless of how C4 later changes single-entity reads.
- Drag-and-drop UX changes — `ReorderableListView` usage and its visuals are untouched; only what happens after `onReorder` fires changes.
- Any schema change — `order_index` columns and table shapes are unchanged; this PRD is about how writes to them are batched, not what they store.

## Further Notes

- Sequencing: this PRD depends on C2 (done — the `Database` seam exists) and is scheduled after C5 in the recommended order `C1 → C5 → C3 → C4 → C6 → C7`.
- The three call sites this PRD replaces are `campaign_screen.dart` (`_reorderChapters`, ~line 181), `chapter_screen.dart` (`_reorder`, ~line 126), and `session_edit_screen.dart` (`_reorder`, ~line 162) — all three currently share the identical four-step shape described in the Problem Statement, down to the same `if (newIndex > oldIndex) newIndex--` line.
- `docs/architecture-review.html#c3` frames the after-state as "one deep module, three call sites" — the pure `reorder` function plus the three seam methods are that deep module; the three notifier methods are the shallow call sites wiring it up.
