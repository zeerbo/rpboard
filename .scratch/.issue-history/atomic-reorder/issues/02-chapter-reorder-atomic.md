# 02 — Chapter reorder becomes atomic, end to end

**What to build:** A DM dragging a Chapter into a new position within a Campaign now gets a reorder that either fully lands or doesn't happen at all — a crash immediately after the drag can no longer leave the Chapter list half old order, half new. The `Database` seam gains `reorderChapters(List<Chapter>)`; `SqfliteDatabase` wraps its writes in one real sqflite transaction and writes only the rows whose `order` actually changed, so a mid-write failure rolls back to the previously persisted order instead of leaving a partial write; `InMemoryDatabase` applies the whole batch as one indivisible synchronous step (no `await` between writes), matching that same all-or-nothing guarantee for tests. `ChapterListNotifier` gains a `reorder(oldIndex, newIndex)` method with the same shape its `add`/`save`/`delete` already have: read its own current list, call the pure `reorder` function from ticket 01, call `reorderChapters`, then invalidate itself. The campaign screen's Chapter list drops its local reorder method — which today mutates the provider's own list in place and writes each row through a separate unguarded call — in favor of passing straight through the two indices `onReorder` hands it; after this ticket that screen no longer reaches the database or touches a list it read from a provider for reordering purposes.

**Blocked by:** 01 — Ordered<T> contract and the pure reorder function.

**Status:** done

- [x] `Database.reorderChapters(List<Chapter>)` added to the seam interface
- [x] `SqfliteDatabase.reorderChapters` writes all changed rows inside one sqflite transaction; a row whose `order` is unchanged from what's persisted is not written
- [x] `InMemoryDatabase.reorderChapters` applies the batch as one indivisible synchronous step
- [x] `ChapterListNotifier.reorder(oldIndex, newIndex)` added, matching the `add`/`save`/`delete` shape: read the current list, call the pure `reorder` function, call `reorderChapters`, then `invalidateSelf()`
- [x] The campaign screen's Chapter list wires `onReorder` straight to the notifier's `reorder(oldIndex, newIndex)`; its old manual reorder method, in-place list mutation, and direct per-row database calls for reordering are deleted
- [x] A `ProviderContainer` test overriding `databaseProvider` with `InMemoryDatabase` seeds a Chapter list, calls `notifier.reorder(oldIndex, newIndex)`, and re-reads through the seam to assert the entities come back in the new order with dense `order_index` values (`0..n-1`)
- [x] Dragging a Chapter in the running app reflects the new order immediately and the order survives an app restart
- [x] `flutter analyze` clean; `flutter test` green
