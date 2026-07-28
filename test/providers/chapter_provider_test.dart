import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/chapter.dart';
import 'package:rpboard/providers/campaign_provider.dart';

import '../support/in_memory_database.dart';

/// Provider-level test for [ChapterListNotifier] — a `.family` notifier keyed by
/// `campaignId`. Same copy-me pattern as the Campaign reference test: a
/// [ProviderContainer] overriding [databaseProvider] with an [InMemoryDatabase],
/// asserting observable read/add/save/delete behavior through the seam, plus the
/// two family-specific guarantees: `order_index ASC` ordering and `campaign_id`
/// foreign-key filtering.
void main() {
  late InMemoryDatabase db;

  Chapter chapter(String id, String campaignId, int order, {String title = ''}) =>
      Chapter(id: id, campaignId: campaignId, order: order, title: title);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => db = InMemoryDatabase());

  test('reads empty when the store has no chapters', () async {
    final container = makeContainer();

    final list = await container.read(chapterListProvider('c1').future);

    expect(list, isEmpty);
  });

  test('add grows the list on re-read', () async {
    final container = makeContainer();
    await container.read(chapterListProvider('c1').future);

    await container
        .read(chapterListProvider('c1').notifier)
        .add(chapter('a', 'c1', 0));

    final list = await container.read(chapterListProvider('c1').future);
    expect(list.map((c) => c.id), ['a']);
  });

  test('re-read is sorted order_index ASC', () async {
    final container = makeContainer();
    final notifier = container.read(chapterListProvider('c1').notifier);

    // Ids are decorrelated from order so the assertion fails if the seam sorts
    // by id instead of order_index: id-ASC would give ['a','b','c'].
    await notifier.add(chapter('a', 'c1', 2));
    await notifier.add(chapter('b', 'c1', 0));
    await notifier.add(chapter('c', 'c1', 1));

    final list = await container.read(chapterListProvider('c1').future);
    expect(list.map((c) => c.id), ['b', 'c', 'a']);
  });

  test('filters by campaign_id — foreign siblings are excluded', () async {
    final container = makeContainer();
    // Seed both campaigns directly through the store.
    await db.insertChapter(chapter('mine', 'c1', 0));
    await db.insertChapter(chapter('theirs', 'c2', 0));

    final list = await container.read(chapterListProvider('c1').future);
    expect(list.map((c) => c.id), ['mine']);
  });

  test('delete is reflected on re-read', () async {
    final container = makeContainer();
    final notifier = container.read(chapterListProvider('c1').notifier);
    await notifier.add(chapter('a', 'c1', 0));
    await notifier.add(chapter('b', 'c1', 1));

    await notifier.delete('a');

    final list = await container.read(chapterListProvider('c1').future);
    expect(list.map((c) => c.id), ['b']);
  });

  test('invalidate re-reads the fake through the seam', () async {
    final container = makeContainer();
    expect(await container.read(chapterListProvider('c1').future), isEmpty);

    await db.insertChapter(chapter('x', 'c1', 0));
    container.invalidate(chapterListProvider('c1'));

    final list = await container.read(chapterListProvider('c1').future);
    expect(list.map((c) => c.id), ['x']);
  });

  test('reorder is reflected on re-read with dense order_index', () async {
    final container = makeContainer();
    final notifier = container.read(chapterListProvider('c1').notifier);
    await notifier.add(chapter('a', 'c1', 0));
    await notifier.add(chapter('b', 'c1', 1));
    await notifier.add(chapter('c', 'c1', 2));

    // Drag the first chapter ('a') to the end.
    await notifier.reorder(0, 3);

    final list = await container.read(chapterListProvider('c1').future);
    expect(list.map((c) => c.id), ['b', 'c', 'a']);
    expect(list.map((c) => c.order), [0, 1, 2]);
  });

  test('reorder through the seam directly returns the new order too', () async {
    final container = makeContainer();
    final notifier = container.read(chapterListProvider('c1').notifier);
    await notifier.add(chapter('a', 'c1', 0));
    await notifier.add(chapter('b', 'c1', 1));

    await notifier.reorder(0, 2); // move 'a' to the end of a 2-item list

    final list = await db.getChapters('c1');
    expect(list.map((c) => c.id), ['b', 'a']);
    expect(list.map((c) => c.order), [0, 1]);
  });

  // ─── Single-item chapterProvider ─────────────────────────────────────────
  //
  // The one writer for an existing Chapter (C4 / ADR-0004). `save` must be
  // visible both on a re-read of `chapterProvider(id)` itself and on a
  // re-read of the parent `chapterListProvider(campaignId)` — the anti-stale
  // regression guarantee this PRD exists to establish.

  test('chapterProvider build returns the correct chapter for a known id', () async {
    final container = makeContainer();
    await db.insertChapter(chapter('a', 'c1', 0, title: 'Original'));

    final result = await container.read(chapterProvider('a').future);

    expect(result?.title, 'Original');
  });

  test('chapterProvider build returns null for an unknown id without throwing', () async {
    final container = makeContainer();

    final result = await container.read(chapterProvider('missing').future);

    expect(result, isNull);
  });

  test('chapterProvider save is observable on a subsequent read of chapterProvider(id)', () async {
    final container = makeContainer();
    await db.insertChapter(chapter('a', 'c1', 0, title: 'Original'));
    await container.read(chapterProvider('a').future);

    await container
        .read(chapterProvider('a').notifier)
        .save(chapter('a', 'c1', 0, title: 'Renamed'));

    final result = await container.read(chapterProvider('a').future);
    expect(result?.title, 'Renamed');
  });

  test('chapterProvider save invalidates chapterListProvider(campaignId) (anti-stale regression)', () async {
    final container = makeContainer();
    await db.insertChapter(chapter('a', 'c1', 0, title: 'Original'));
    await container.read(chapterListProvider('c1').future);

    await container
        .read(chapterProvider('a').notifier)
        .save(chapter('a', 'c1', 0, title: 'Renamed'));

    final list = await container.read(chapterListProvider('c1').future);
    expect(list.single.title, 'Renamed');
  });
}
