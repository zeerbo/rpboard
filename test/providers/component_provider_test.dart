import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/component.dart';
import 'package:rpboard/providers/campaign_provider.dart';

import '../support/in_memory_database.dart';

/// Provider-level test for [ComponentListNotifier] — a `.family` notifier keyed
/// by `screenId`. Mirrors the Campaign reference test: [ProviderContainer] over
/// an [InMemoryDatabase] wired through [databaseProvider], asserting observable
/// read/add/save/delete plus `order_index ASC` ordering and `screen_id`
/// foreign-key filtering.
///
/// Because [InMemoryDatabase] rebuilds every read as
/// `SessionComponent.fromMap(stored.toMap())`, a provider-level read here
/// genuinely exercises [ComponentData.toJson]/[ComponentData.fromDb] and kind
/// dispatch, not a shortcut around them.
void main() {
  late InMemoryDatabase db;

  SessionComponent component(String id, String screenId, int order, ComponentData data) =>
      SessionComponent(
        id: id,
        screenId: screenId,
        order: order,
        data: data,
      );

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => db = InMemoryDatabase());

  test('reads empty when the store has no components', () async {
    final container = makeContainer();

    final list = await container.read(componentListProvider('s1').future);

    expect(list, isEmpty);
  });

  test('add grows the list on re-read', () async {
    final container = makeContainer();
    await container.read(componentListProvider('s1').future);

    await container
        .read(componentListProvider('s1').notifier)
        .add(component('a', 's1', 0, NarrativeTextData.empty()));

    final list = await container.read(componentListProvider('s1').future);
    expect(list.map((c) => c.id), ['a']);
  });

  test('re-read is sorted order_index ASC', () async {
    final container = makeContainer();
    final notifier = container.read(componentListProvider('s1').notifier);

    // Ids are decorrelated from order so the assertion fails if the seam sorts
    // by id instead of order_index: id-ASC would give ['a','b','c'].
    await notifier.add(component('a', 's1', 2, NarrativeTextData.empty()));
    await notifier.add(component('b', 's1', 0, NarrativeTextData.empty()));
    await notifier.add(component('c', 's1', 1, NarrativeTextData.empty()));

    final list = await container.read(componentListProvider('s1').future);
    expect(list.map((c) => c.id), ['b', 'c', 'a']);
  });

  test('filters by screen_id — foreign siblings are excluded', () async {
    final container = makeContainer();
    await db.insertComponent(component('mine', 's1', 0, NarrativeTextData.empty()));
    await db.insertComponent(component('theirs', 's2', 0, NarrativeTextData.empty()));

    final list = await container.read(componentListProvider('s1').future);
    expect(list.map((c) => c.id), ['mine']);
  });

  test('save is reflected on re-read', () async {
    final container = makeContainer();
    final notifier = container.read(componentListProvider('s1').notifier);
    await notifier.add(component('a', 's1', 0, NarrativeTextData.empty()));

    await notifier.save(component('a', 's1', 0, InitiativeTrackerData.empty()));

    final list = await container.read(componentListProvider('s1').future);
    expect(list.single.data, isA<InitiativeTrackerData>());
  });

  test('delete is reflected on re-read', () async {
    final container = makeContainer();
    final notifier = container.read(componentListProvider('s1').notifier);
    await notifier.add(component('a', 's1', 0, NarrativeTextData.empty()));
    await notifier.add(component('b', 's1', 1, NarrativeTextData.empty()));

    await notifier.delete('a');

    final list = await container.read(componentListProvider('s1').future);
    expect(list.map((c) => c.id), ['b']);
  });

  test('invalidate re-reads the fake through the seam', () async {
    final container = makeContainer();
    expect(await container.read(componentListProvider('s1').future), isEmpty);

    await db.insertComponent(component('x', 's1', 0, NarrativeTextData.empty()));
    container.invalidate(componentListProvider('s1'));

    final list = await container.read(componentListProvider('s1').future);
    expect(list.map((c) => c.id), ['x']);
  });

  test('reorder is reflected on re-read with dense order_index', () async {
    final container = makeContainer();
    final notifier = container.read(componentListProvider('s1').notifier);
    await notifier.add(component('a', 's1', 0, NarrativeTextData.empty()));
    await notifier.add(component('b', 's1', 1, NarrativeTextData.empty()));
    await notifier.add(component('c', 's1', 2, NarrativeTextData.empty()));

    // Drag the middle component ('b') to the front.
    await notifier.reorder(1, 0);

    final list = await container.read(componentListProvider('s1').future);
    expect(list.map((c) => c.id), ['b', 'a', 'c']);
    expect(list.map((c) => c.order), [0, 1, 2]);
  });

  test('reorder preserves each component\'s payload', () async {
    final container = makeContainer();
    final notifier = container.read(componentListProvider('s1').notifier);
    await notifier.add(component('a', 's1', 0, NarrativeTextData.empty()..title = 'A'));
    await notifier.add(component('b', 's1', 1, InitiativeTrackerData.empty()));

    await notifier.reorder(0, 2); // move 'a' to the end of a 2-item list

    final list = await db.getComponents('s1');
    expect(list.map((c) => c.id), ['b', 'a']);
    expect(list[0].data, isA<InitiativeTrackerData>());
    expect((list[1].data as NarrativeTextData).title, 'A');
  });

  group('typed ComponentData round-trip', () {
    for (final kind in ComponentData.kinds) {
      test('${kind.dbKey} persists and re-reads as the matching subclass', () async {
        final container = makeContainer();
        final notifier = container.read(componentListProvider('s1').notifier);

        await notifier.add(component('c-${kind.dbKey}', 's1', 0, kind.empty()));

        final list = await container.read(componentListProvider('s1').future);
        expect(list.single.data.runtimeType, kind.empty().runtimeType);
        expect(list.single.data.dbKey, kind.dbKey);
      });
    }

    test('unrecognized kind round-trips as UnknownComponentData with kind and json intact', () async {
      final container = makeContainer();
      final notifier = container.read(componentListProvider('s1').notifier);

      await notifier.add(component(
        'a',
        's1',
        0,
        UnknownComponentData(rawType: 'futureKind', rawJson: '{"foo":"bar"}'),
      ));

      final list = await container.read(componentListProvider('s1').future);
      final data = list.single.data;
      expect(data, isA<UnknownComponentData>());
      data as UnknownComponentData;
      expect(data.rawType, 'futureKind');
      expect(data.rawJson, '{"foo":"bar"}');
    });

    test('recognized kind with malformed json degrades to UnknownComponentData, bytes preserved', () async {
      final container = makeContainer();
      final notifier = container.read(componentListProvider('s1').notifier);

      // A recognized dbKey (narrativeText) paired with corrupt JSON — as if an
      // interrupted write truncated the row. toMap() writes this back verbatim
      // via UnknownComponentData.toJson(), so persistence never throws either.
      await notifier.add(component(
        'a',
        's1',
        0,
        UnknownComponentData(rawType: 'narrativeText', rawJson: '{not valid json'),
      ));

      final list = await container.read(componentListProvider('s1').future);
      final data = list.single.data;
      expect(data, isA<UnknownComponentData>());
      data as UnknownComponentData;
      expect(data.rawType, 'narrativeText');
      expect(data.rawJson, '{not valid json');
    });
  });
}
