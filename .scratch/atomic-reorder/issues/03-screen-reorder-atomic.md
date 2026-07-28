# 03 — SessionScreen reorder becomes atomic, end to end

**What to build:** The same reliability guarantee ticket 02 gives Chapters now applies to a Chapter's SessionScreens ("Scene"): dragging one into a new position either fully lands or doesn't happen at all, with no possibility of a crash leaving the list half old order, half new. The `Database` seam gains `reorderScreens(List<SessionScreen>)`; `SqfliteDatabase` wraps its writes in one real sqflite transaction and writes only the rows whose `order` actually changed; `InMemoryDatabase` applies the whole batch as one indivisible synchronous step, matching that guarantee for tests. `ScreenListNotifier` gains a `reorder(oldIndex, newIndex)` method with the same shape its `add`/`save`/`delete` already have: read its own current list, call the pure `reorder` function from ticket 01, call `reorderScreens`, then invalidate itself. The chapter screen's SessionScreen list drops its local reorder method — which today mutates the provider's own list in place and writes each row through a separate unguarded call — in favor of passing straight through the two indices `onReorder` hands it; after this ticket that screen no longer reaches the database or touches a list it read from a provider for reordering purposes.

**Blocked by:** 01 — Ordered<T> contract and the pure reorder function.

**Status:** done

- [x] `Database.reorderScreens(List<SessionScreen>)` added to the seam interface
- [x] `SqfliteDatabase.reorderScreens` writes all changed rows inside one sqflite transaction; a row whose `order` is unchanged from what's persisted is not written
- [x] `InMemoryDatabase.reorderScreens` applies the batch as one indivisible synchronous step
- [x] `ScreenListNotifier.reorder(oldIndex, newIndex)` added, matching the `add`/`save`/`delete` shape: read the current list, call the pure `reorder` function, call `reorderScreens`, then `invalidateSelf()`
- [x] The chapter screen's SessionScreen list wires `onReorder` straight to the notifier's `reorder(oldIndex, newIndex)`; its old manual reorder method, in-place list mutation, and direct per-row database calls for reordering are deleted
- [x] A `ProviderContainer` test overriding `databaseProvider` with `InMemoryDatabase` seeds a SessionScreen list, calls `notifier.reorder(oldIndex, newIndex)`, and re-reads through the seam to assert the entities come back in the new order with dense `order_index` values (`0..n-1`)
- [x] Dragging a Scena in the running app reflects the new order immediately and the order survives an app restart
- [x] `flutter analyze` clean; `flutter test` green
