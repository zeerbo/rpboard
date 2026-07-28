import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/campaign.dart';
import 'package:rpboard/providers/campaign_provider.dart';

import '../support/in_memory_database.dart';

/// First provider-level test in the repo. It exercises [CampaignListNotifier]
/// end-to-end against an [InMemoryDatabase] wired through [databaseProvider] —
/// pure Dart, no widget pump, no real SQLite. This is the copy-me pattern for
/// the remaining families (chapters, screens, components, characters).
///
/// Assertions are about observable behavior only: what re-reading the provider
/// returns. No private fields, no call counts, no "ref.read was invoked".
void main() {
  late InMemoryDatabase db;

  Campaign campaign(String id, String name, DateTime updatedAt) => Campaign(
        id: id,
        name: name,
        createdAt: DateTime(2020),
        updatedAt: updatedAt,
      );

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => db = InMemoryDatabase());

  test('reads empty when the store has no campaigns', () async {
    final container = makeContainer();

    final list = await container.read(campaignListProvider.future);

    expect(list, isEmpty);
  });

  test('add grows the list on re-read', () async {
    final container = makeContainer();
    await container.read(campaignListProvider.future); // materialize empty

    await container
        .read(campaignListProvider.notifier)
        .add(campaign('a', 'Alpha', DateTime(2024, 1, 1)));

    final list = await container.read(campaignListProvider.future);
    expect(list.map((c) => c.id), ['a']);
  });

  test('re-read is sorted updated_at DESC', () async {
    final container = makeContainer();
    final notifier = container.read(campaignListProvider.notifier);

    await notifier.add(campaign('old', 'Old', DateTime(2024, 1, 1)));
    await notifier.add(campaign('new', 'New', DateTime(2024, 6, 1)));
    await notifier.add(campaign('mid', 'Mid', DateTime(2024, 3, 1)));

    final list = await container.read(campaignListProvider.future);
    expect(list.map((c) => c.id), ['new', 'mid', 'old']);
  });

  test('delete is reflected on re-read', () async {
    final container = makeContainer();
    final notifier = container.read(campaignListProvider.notifier);
    await notifier.add(campaign('a', 'Alpha', DateTime(2024, 1, 1)));
    await notifier.add(campaign('b', 'Beta', DateTime(2024, 2, 1)));

    await notifier.delete('a');

    final list = await container.read(campaignListProvider.future);
    expect(list.map((c) => c.id), ['b']);
  });

  test('invalidate re-reads the fake through the seam', () async {
    final container = makeContainer();
    // First read materializes an empty list.
    expect(await container.read(campaignListProvider.future), isEmpty);

    // Mutate the store directly, bypassing the notifier, then invalidate.
    // A fresh read must reflect the external write — proof the provider is
    // bound to the overridden database, not a cached snapshot.
    await db.insertCampaign(campaign('x', 'External', DateTime(2024, 1, 1)));
    container.invalidate(campaignListProvider);

    final list = await container.read(campaignListProvider.future);
    expect(list.map((c) => c.id), ['x']);
  });

  // ─── Single-item campaignProvider ───────────────────────────────────────
  //
  // The one writer for an existing Campaign (C4 / ADR-0004). `save` must be
  // visible both on a re-read of `campaignProvider(id)` itself and on a
  // re-read of the parent `campaignListProvider` — the anti-stale regression
  // guarantee this PRD exists to establish.

  test('campaignProvider build returns the correct campaign for a known id', () async {
    final container = makeContainer();
    await db.insertCampaign(campaign('a', 'Alpha', DateTime(2024, 1, 1)));

    final result = await container.read(campaignProvider('a').future);

    expect(result?.name, 'Alpha');
  });

  test('campaignProvider build returns null for an unknown id without throwing', () async {
    final container = makeContainer();

    final result = await container.read(campaignProvider('missing').future);

    expect(result, isNull);
  });

  test('campaignProvider save is observable on a subsequent read of campaignProvider(id)', () async {
    final container = makeContainer();
    await db.insertCampaign(campaign('a', 'Original', DateTime(2024, 1, 1)));
    await container.read(campaignProvider('a').future);

    await container
        .read(campaignProvider('a').notifier)
        .save(campaign('a', 'Renamed', DateTime(2024, 2, 1)));

    final result = await container.read(campaignProvider('a').future);
    expect(result?.name, 'Renamed');
  });

  test('campaignProvider save invalidates campaignListProvider (anti-stale regression)', () async {
    final container = makeContainer();
    await db.insertCampaign(campaign('a', 'Original', DateTime(2024, 1, 1)));
    // Materialize the list before the single-item save, so this proves the
    // save invalidates an already-read list, not just a fresh one.
    await container.read(campaignListProvider.future);

    await container
        .read(campaignProvider('a').notifier)
        .save(campaign('a', 'Renamed', DateTime(2024, 2, 1)));

    final list = await container.read(campaignListProvider.future);
    expect(list.single.name, 'Renamed');
  });
}
