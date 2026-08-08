# 04 — SessionComponent reorder becomes atomic, end to end; all three call sites cut over

**What to build:** The same reliability guarantee tickets 02 and 03 gave Chapters and SessionScreens now applies to the SessionComponents on a SessionScreen: dragging one into a new position in Edit Mode either fully lands or doesn't happen at all. The `Database` seam gains `reorderComponents(List<SessionComponent>)`; `SqfliteDatabase` wraps its writes in one real sqflite transaction and writes only the rows whose `order` actually changed; `InMemoryDatabase` applies the whole batch as one indivisible synchronous step, matching that guarantee for tests. `ComponentListNotifier` gains a `reorder(oldIndex, newIndex)` method with the same shape its `add`/`save`/`delete` already have: read its own current list, call the pure `reorder` function from ticket 01, call `reorderComponents`, then invalidate itself. The session edit screen's component list drops its local reorder method — which today mutates the provider's own list in place and writes each row through a separate unguarded call — in favor of passing straight through the two indices `onReorder` hands it. With this ticket, all three reorderable lists in the app (Chapter, SessionScreen, SessionComponent) share the identical reliability guarantee and the identical shallow call-site shape; none of the three Master Mode screens touches the database or a provider-owned list directly to reorder anything anymore.

**Blocked by:** 01 — Ordered<T> contract and the pure reorder function.

**Status:** done

- [x] `Database.reorderComponents(List<SessionComponent>)` added to the seam interface
- [x] `SqfliteDatabase.reorderComponents` writes all changed rows inside one sqflite transaction; a row whose `order` is unchanged from what's persisted is not written
- [x] `InMemoryDatabase.reorderComponents` applies the batch as one indivisible synchronous step
- [x] `ComponentListNotifier.reorder(oldIndex, newIndex)` added, matching the `add`/`save`/`delete` shape: read the current list, call the pure `reorder` function, call `reorderComponents`, then `invalidateSelf()`
- [x] The session edit screen's component list (Edit Mode) wires `onReorder` straight to the notifier's `reorder(oldIndex, newIndex)`; its old manual reorder method, in-place list mutation, and direct per-row database calls for reordering are deleted
- [x] A `ProviderContainer` test overriding `databaseProvider` with `InMemoryDatabase` seeds a SessionComponent list, calls `notifier.reorder(oldIndex, newIndex)`, and re-reads through the seam to assert the entities come back in the new order with dense `order_index` values (`0..n-1`)
- [x] Dragging a component in the running app (Edit Mode) reflects the new order immediately and the order survives an app restart
- [x] Confirmed across all three screens (`campaign_screen.dart`, `chapter_screen.dart`, `session_edit_screen.dart`): none imports `databaseProvider` for reordering purposes and none mutates a list it read from a provider — reordering is entirely a list-notifier concern
- [x] `flutter analyze` clean; `flutter test` green
