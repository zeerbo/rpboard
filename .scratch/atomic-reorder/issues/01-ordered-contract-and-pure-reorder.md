# 01 — Ordered<T> contract and the pure reorder function

**What to build:** A shared `Ordered<T>` contract and a pure, generic reorder function become the one place index math and reindexing logic live, written exactly once instead of copy-pasted per screen. `Ordered<T>` exposes an id, an order, and a `withOrder(int)` method that returns a brand-new instance carrying that order — never a mutating setter, so nothing can make "purity" only apparent. Chapter, SessionScreen, and SessionComponent each implement `Ordered<T>`, gaining a small `copyWith`-style method to back `withOrder`; this is the first thing any of the three models needs beyond field mutation and `fromMap`/`toMap`. The pure function takes a list of `Ordered` entities plus the two indices `ReorderableListView.onReorder` reports, absorbs the `newIndex > oldIndex` decrement internally so no caller repeats it, and returns a brand-new, densely zero-indexed list built from brand-new instances — the input list and every one of its elements are left completely untouched. Nothing user-facing changes yet: the three Master Mode screens keep their existing per-screen reorder loops for now, so the app behaves exactly as it did before this ticket. This ticket is the deep module the next three tickets each wire up as a thin call site.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] `abstract interface class Ordered<T>` exists, exposing `String get id`, `int get order`, and `T withOrder(int order)`
- [x] Chapter, SessionScreen, and SessionComponent each implement `Ordered<T>` via a small local `copyWith`-style method backing `withOrder`; every existing field, constructor, `fromMap`, and `toMap` on all three is otherwise unchanged
- [x] A pure `reorder<T extends Ordered<T>>(List<T> list, int oldIndex, int newIndex) -> List<T>` function lives in its own module under the core layer, separate from any model or provider code
- [x] The function owns the `ReorderableListView` index-convention adjustment internally — no caller needs to decrement `newIndex` itself
- [x] Unit tests exercise the function directly against a tiny fake `Ordered` implementation, with no Flutter widget pump and no database in the picture: move an item down, move an item up, move first to last, move last to first, a no-op reorder (same start and end position), a single-element list, and an empty list
- [x] Tests assert all of: the returned list is a new list object; the original input list is left unchanged; none of the original input instances are mutated; the result's `order` values are a dense `0..n-1` sequence
- [x] `campaign_screen.dart`, `chapter_screen.dart`, and `session_edit_screen.dart` are untouched and the app's reorder behavior is unchanged
- [x] `flutter analyze` clean; `flutter test` green
