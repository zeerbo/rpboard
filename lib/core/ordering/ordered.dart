/// Shared contract for entities that live in a reorderable list — see
/// `reorder.dart` in this module for the pure function built on top of it.
///
/// [withOrder] must return a brand-new instance carrying the given order,
/// never mutate in place. A mutating `set order` would let [reorder] "work"
/// while still mutating instances a caller still holds a reference to
/// elsewhere (e.g. a provider's own state) — purity would be only apparent.
/// See ADR-0003.
abstract interface class Ordered<T> {
  String get id;
  int get order;
  T withOrder(int order);
}
