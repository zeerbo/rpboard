import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/ordering/ordered.dart';
import 'package:rpboard/core/ordering/reorder.dart';

/// Tiny fake [Ordered] implementation — no Flutter, no database, no model
/// from `lib/models/`. Immutable-by-convention: [withOrder] returns a new
/// instance, [id] never changes.
class FakeOrdered implements Ordered<FakeOrdered> {
  @override
  final String id;
  @override
  final int order;

  const FakeOrdered(this.id, this.order);

  @override
  FakeOrdered withOrder(int order) => FakeOrdered(id, order);

  @override
  String toString() => 'FakeOrdered($id, $order)';
}

List<FakeOrdered> listOf(List<String> ids) =>
    [for (var i = 0; i < ids.length; i++) FakeOrdered(ids[i], i)];

void main() {
  group('reorder', () {
    test('move down shifts items between old and new position back one', () {
      final input = listOf(['a', 'b', 'c', 'd']);

      final result = reorder(input, 0, 3);

      expect(result.map((e) => e.id), ['b', 'c', 'a', 'd']);
    });

    test('move up shifts items between new and old position forward one', () {
      final input = listOf(['a', 'b', 'c', 'd']);

      final result = reorder(input, 3, 1);

      expect(result.map((e) => e.id), ['a', 'd', 'b', 'c']);
    });

    test('move first to last', () {
      final input = listOf(['a', 'b', 'c']);

      final result = reorder(input, 0, 3);

      expect(result.map((e) => e.id), ['b', 'c', 'a']);
    });

    test('move last to first', () {
      final input = listOf(['a', 'b', 'c']);

      final result = reorder(input, 2, 0);

      expect(result.map((e) => e.id), ['c', 'a', 'b']);
    });

    test('no-op reorder (same start and end position) leaves order unchanged', () {
      final input = listOf(['a', 'b', 'c']);

      final result = reorder(input, 1, 1);

      expect(result.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('single-element list', () {
      final input = listOf(['a']);

      final result = reorder(input, 0, 0);

      expect(result.map((e) => e.id), ['a']);
      expect(result.single.order, 0);
    });

    test('empty list', () {
      final result = reorder(<FakeOrdered>[], 0, 0);

      expect(result, isEmpty);
    });

    test('returns a new list object', () {
      final input = listOf(['a', 'b', 'c']);

      final result = reorder(input, 0, 2);

      expect(identical(result, input), isFalse);
    });

    test('the original input list is left unchanged', () {
      final input = listOf(['a', 'b', 'c']);
      final inputIdsBefore = input.map((e) => e.id).toList();
      final inputOrdersBefore = input.map((e) => e.order).toList();

      reorder(input, 0, 2);

      expect(input.map((e) => e.id).toList(), inputIdsBefore);
      expect(input.map((e) => e.order).toList(), inputOrdersBefore);
    });

    test('none of the original input instances are mutated', () {
      final input = listOf(['a', 'b', 'c']);
      final originalInstances = List<FakeOrdered>.of(input);

      final result = reorder(input, 0, 2);

      // Every original instance is untouched...
      for (var i = 0; i < input.length; i++) {
        expect(identical(input[i], originalInstances[i]), isTrue);
        expect(input[i].order, i); // original orders (0,1,2) still intact
      }
      // ...and the result is built from brand-new instances, not the old ones.
      for (final original in originalInstances) {
        expect(result.any((r) => identical(r, original)), isFalse);
      }
    });

    test('result order values are a dense 0..n-1 sequence', () {
      // Seed with non-dense, out-of-order values to prove reindexing happens.
      final input = [
        const FakeOrdered('a', 10),
        const FakeOrdered('b', 20),
        const FakeOrdered('c', 30),
        const FakeOrdered('d', 40),
      ];

      final result = reorder(input, 3, 0);

      expect(result.map((e) => e.order).toList(), [0, 1, 2, 3]);
      expect(result.map((e) => e.id).toList(), ['d', 'a', 'b', 'c']);
    });
  });
}
