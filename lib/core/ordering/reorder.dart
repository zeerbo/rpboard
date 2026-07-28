import 'ordered.dart';

/// Pure, generic reorder for anything implementing [Ordered]. Given a list
/// and the two indices `ReorderableListView.onReorder` reports, returns a
/// brand-new, densely-reindexed (`0..n-1`) list built from brand-new
/// instances.
///
/// Never mutates [list] or any of its elements — the input list and every
/// element in it are left exactly as they were. Owns the
/// `ReorderableListView` index-convention adjustment internally
/// (`if (newIndex > oldIndex) newIndex--`), so no caller repeats it.
List<T> reorder<T extends Ordered<T>>(List<T> list, int oldIndex, int newIndex) {
  if (list.isEmpty) return <T>[];

  final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;

  final working = List<T>.of(list); // copy — never touch the caller's list
  final item = working.removeAt(oldIndex);
  working.insert(adjustedNewIndex, item);

  return [
    for (var i = 0; i < working.length; i++) working[i].withOrder(i),
  ];
}
