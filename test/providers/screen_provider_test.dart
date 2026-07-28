import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/session_screen.dart';
import 'package:rpboard/providers/campaign_provider.dart';

import '../support/in_memory_database.dart';

/// Provider-level test for [ScreenListNotifier] — a `.family` notifier keyed by
/// `chapterId`. Mirrors the Campaign reference test: [ProviderContainer] over an
/// [InMemoryDatabase] wired through [databaseProvider], asserting observable
/// read/add/save/delete plus `order_index ASC` ordering and `chapter_id`
/// foreign-key filtering.
void main() {
  late InMemoryDatabase db;

  SessionScreen screen(String id, String chapterId, int order,
          {String title = ''}) =>
      SessionScreen(id: id, chapterId: chapterId, order: order, title: title);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => db = InMemoryDatabase());

  test('reads empty when the store has no screens', () async {
    final container = makeContainer();

    final list = await container.read(screenListProvider('ch1').future);

    expect(list, isEmpty);
  });

  test('add grows the list on re-read', () async {
    final container = makeContainer();
    await container.read(screenListProvider('ch1').future);

    await container
        .read(screenListProvider('ch1').notifier)
        .add(screen('a', 'ch1', 0));

    final list = await container.read(screenListProvider('ch1').future);
    expect(list.map((s) => s.id), ['a']);
  });

  test('re-read is sorted order_index ASC', () async {
    final container = makeContainer();
    final notifier = container.read(screenListProvider('ch1').notifier);

    // Ids are decorrelated from order so the assertion fails if the seam sorts
    // by id instead of order_index: id-ASC would give ['a','b','c'].
    await notifier.add(screen('a', 'ch1', 2));
    await notifier.add(screen('b', 'ch1', 0));
    await notifier.add(screen('c', 'ch1', 1));

    final list = await container.read(screenListProvider('ch1').future);
    expect(list.map((s) => s.id), ['b', 'c', 'a']);
  });

  test('filters by chapter_id — foreign siblings are excluded', () async {
    final container = makeContainer();
    await db.insertScreen(screen('mine', 'ch1', 0));
    await db.insertScreen(screen('theirs', 'ch2', 0));

    final list = await container.read(screenListProvider('ch1').future);
    expect(list.map((s) => s.id), ['mine']);
  });

  test('delete is reflected on re-read', () async {
    final container = makeContainer();
    final notifier = container.read(screenListProvider('ch1').notifier);
    await notifier.add(screen('a', 'ch1', 0));
    await notifier.add(screen('b', 'ch1', 1));

    await notifier.delete('a');

    final list = await container.read(screenListProvider('ch1').future);
    expect(list.map((s) => s.id), ['b']);
  });

  test('invalidate re-reads the fake through the seam', () async {
    final container = makeContainer();
    expect(await container.read(screenListProvider('ch1').future), isEmpty);

    await db.insertScreen(screen('x', 'ch1', 0));
    container.invalidate(screenListProvider('ch1'));

    final list = await container.read(screenListProvider('ch1').future);
    expect(list.map((s) => s.id), ['x']);
  });

  test('reorder is reflected on re-read with dense order_index', () async {
    final container = makeContainer();
    final notifier = container.read(screenListProvider('ch1').notifier);
    await notifier.add(screen('a', 'ch1', 0));
    await notifier.add(screen('b', 'ch1', 1));
    await notifier.add(screen('c', 'ch1', 2));

    // Drag the last screen ('c') to the front.
    await notifier.reorder(2, 0);

    final list = await container.read(screenListProvider('ch1').future);
    expect(list.map((s) => s.id), ['c', 'a', 'b']);
    expect(list.map((s) => s.order), [0, 1, 2]);
  });

  test('reorder through the seam directly returns the new order too', () async {
    final container = makeContainer();
    final notifier = container.read(screenListProvider('ch1').notifier);
    await notifier.add(screen('a', 'ch1', 0));
    await notifier.add(screen('b', 'ch1', 1));

    await notifier.reorder(0, 2); // move 'a' to the end of a 2-item list

    final list = await db.getScreens('ch1');
    expect(list.map((s) => s.id), ['b', 'a']);
    expect(list.map((s) => s.order), [0, 1]);
  });

  // ─── Single-item screenProvider ──────────────────────────────────────────
  //
  // The one writer for an existing SessionScreen (C4 / ADR-0004). `save`
  // must be visible both on a re-read of `screenProvider(id)` itself and on
  // a re-read of the parent `screenListProvider(chapterId)` — the anti-stale
  // regression guarantee this PRD exists to establish.

  test('screenProvider build returns the correct screen for a known id', () async {
    final container = makeContainer();
    await db.insertScreen(screen('a', 'ch1', 0, title: 'Original'));

    final result = await container.read(screenProvider('a').future);

    expect(result?.title, 'Original');
  });

  test('screenProvider build returns null for an unknown id without throwing', () async {
    final container = makeContainer();

    final result = await container.read(screenProvider('missing').future);

    expect(result, isNull);
  });

  test('screenProvider save is observable on a subsequent read of screenProvider(id)', () async {
    final container = makeContainer();
    await db.insertScreen(screen('a', 'ch1', 0, title: 'Original'));
    await container.read(screenProvider('a').future);

    await container
        .read(screenProvider('a').notifier)
        .save(screen('a', 'ch1', 0, title: 'Renamed'));

    final result = await container.read(screenProvider('a').future);
    expect(result?.title, 'Renamed');
  });

  test('screenProvider save invalidates screenListProvider(chapterId) (anti-stale regression)', () async {
    final container = makeContainer();
    await db.insertScreen(screen('a', 'ch1', 0, title: 'Original'));
    await container.read(screenListProvider('ch1').future);

    await container
        .read(screenProvider('a').notifier)
        .save(screen('a', 'ch1', 0, title: 'Renamed'));

    final list = await container.read(screenListProvider('ch1').future);
    expect(list.single.title, 'Renamed');
  });
}
