---
status: accepted
---

# Atomic reorder replaces per-screen reorder loops

Reordering a Chapter list, a SessionScreen list, or a SessionComponent list was implemented identically in three screens (`campaign_screen.dart`, `chapter_screen.dart`, `session_edit_screen.dart`): remove the dragged item, re-insert it at its new index, loop over the whole list writing a new `order` to every row through N separate `update` calls, then invalidate the provider. The loop mutated in place the very list instance the provider's `AsyncValue` owned, and the N writes had no transaction around them, so a crash mid-loop left `order_index` incoherent. We replace this with a deep module: a pure generic function `reorder<T extends Ordered<T>>(list, oldIndex, newIndex)` under `lib/core/ordering/` that reindexes a list without mutating its input, a shared `Ordered<T>` contract (`id`, `order`, `withOrder`) that Chapter, SessionScreen, and SessionComponent implement, and three new `Database` seam methods — `reorderChapters`, `reorderScreens`, `reorderComponents` — each writing its changed rows inside a single transaction. `ChapterListNotifier`, `ScreenListNotifier`, and `ComponentListNotifier` each gain a `reorder(oldIndex, newIndex)` method with the same shape as their existing `add`/`save`/`delete`; the three screens shrink to passing two indices and no longer touch the database or a provider-owned list directly.

## Considered Options

- **A generic `transaction(callback)` primitive on the `Database` seam** — rejected. It leaks the transaction concept out past the seam into caller code, and forces `InMemoryDatabase` to simulate rollback semantics it has no natural way to express faithfully. Three narrow, typed methods keep the transaction boundary entirely inside the two adapters.
- **A stringly-typed `saveOrder(table, ids)` method** — rejected. It leaks table names into caller code and loses type safety: nothing stops a caller from passing chapter ids to the screens table, and the compiler can't catch it. Three separate, typed methods (`reorderChapters`, `reorderScreens`, `reorderComponents`) make the same mistake a compile error.
- **A mutating `set order` on the `Ordered<T>` contract** instead of `withOrder(int) -> T` — rejected. A setter lets the reorder function "work" while still mutating instances the provider still holds a reference to elsewhere in memory; purity would be only apparent. Returning a new instance from `withOrder` is the only shape where "the input is untouched" is actually true.
- **Reordering a bare `List<String>` of ids** instead of a list of entities implementing `Ordered<T>` — rejected. It pushes id-to-entity lookup and re-hydration into every notifier that wants to reorder, reintroducing per-call-site duplication that this module exists to remove.
- **Doing this inside C4 (single-item providers)** — rejected as scope mixing. Reordering is a collection operation on the existing list notifiers; it does not depend on and is not affected by C4's later "only the single-item provider writes" rule, so bundling them would couple two independent decisions.

## Consequences

- **This amends ADR-0002.** ADR-0002 recorded "no transaction primitive added — that is C3's decision" as one of its consequences. This ADR is that decision: the seam gains exactly three transactional methods, not a general primitive, and ADR-0002's consequence should be read as resolved by this one.
- **`SqfliteDatabase` wraps each of the three methods in a single sqflite transaction**, writing only the rows whose `order` actually changed. A failure partway through rolls back to the previously persisted order rather than leaving a partial write.
- **`InMemoryDatabase` applies each batch as one indivisible synchronous step**, matching the real adapter's all-or-nothing behavior as an observable contract. Its batch semantics must stay aligned with `SqfliteDatabase`'s if either changes, the same divergence risk ADR-0002 already flagged for ordering and filtering.
- **Chapter, SessionScreen, and SessionComponent each gain a small local `copyWith`-style method** to back `Ordered<T>.withOrder`. This is the first place these three models need anything beyond field mutation and `fromMap`/`toMap`.
- **The three screens no longer import `databaseProvider` for reordering** and no longer mutate a list they read from a provider; they pass two integers to their list notifier's new `reorder` method. This is a strict narrowing of what a screen is allowed to touch, consistent with the direction ADR-0002 started.
- **Campaign stays unreordered.** It has no `order` field and is listed by `updated_at DESC`, so it does not implement `Ordered<T>` and gets none of these three seam methods.
- **Reordering remains a list-notifier concern**, not a single-item one — this decision is explicitly orthogonal to C4 and does not need revisiting when C4 lands.
