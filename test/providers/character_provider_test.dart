import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/providers/character_provider.dart';

import '../support/in_memory_database.dart';

/// Provider-level test for [CharacterListNotifier] — a flat (non-family)
/// notifier, like Campaign. Mirrors the reference test: [ProviderContainer] over
/// an [InMemoryDatabase] wired through [databaseProvider], asserting observable
/// read/add/save/delete plus `name ASC` ordering (characters have no FK filter).
void main() {
  late InMemoryDatabase db;

  Character character(String id, String name) => Character(id: id, name: name);

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => db = InMemoryDatabase());

  test('reads empty when the store has no characters', () async {
    final container = makeContainer();

    final list = await container.read(characterListProvider.future);

    expect(list, isEmpty);
  });

  test('add grows the list on re-read', () async {
    final container = makeContainer();
    await container.read(characterListProvider.future);

    await container
        .read(characterListProvider.notifier)
        .add(character('a', 'Aragorn'));

    final list = await container.read(characterListProvider.future);
    expect(list.map((c) => c.id), ['a']);
  });

  test('re-read is sorted name ASC', () async {
    final container = makeContainer();
    final notifier = container.read(characterListProvider.notifier);

    // Ids are decorrelated from name so the assertion fails if the seam sorts
    // by id instead of name: id-ASC would give ['a','b','c'] → Gandalf first.
    await notifier.add(character('a', 'Gandalf'));
    await notifier.add(character('b', 'Aragorn'));
    await notifier.add(character('c', 'Boromir'));

    final list = await container.read(characterListProvider.future);
    expect(list.map((c) => c.id), ['b', 'c', 'a']);
    expect(list.map((c) => c.name), ['Aragorn', 'Boromir', 'Gandalf']);
  });

  test('delete is reflected on re-read', () async {
    final container = makeContainer();
    final notifier = container.read(characterListProvider.notifier);
    await notifier.add(character('a', 'Aragorn'));
    await notifier.add(character('b', 'Boromir'));

    await notifier.delete('a');

    final list = await container.read(characterListProvider.future);
    expect(list.map((c) => c.id), ['b']);
  });

  test('invalidate re-reads the fake through the seam', () async {
    final container = makeContainer();
    expect(await container.read(characterListProvider.future), isEmpty);

    await db.insertCharacter(character('x', 'External'));
    container.invalidate(characterListProvider);

    final list = await container.read(characterListProvider.future);
    expect(list.map((c) => c.id), ['x']);
  });

  // ─── Single-item characterProvider ──────────────────────────────────────
  //
  // The one writer for an existing Character (C4 / ADR-0004) — the PRD's
  // headline bug fix: CharacterSheetScreen's debounce-save used to bypass
  // the provider graph entirely, leaving characterListProvider stale.

  test('characterProvider build returns the correct character for a known id', () async {
    final container = makeContainer();
    await db.insertCharacter(character('a', 'Aragorn'));

    final result = await container.read(characterProvider('a').future);

    expect(result?.name, 'Aragorn');
  });

  test('characterProvider build returns null for an unknown id without throwing', () async {
    final container = makeContainer();

    final result = await container.read(characterProvider('missing').future);

    expect(result, isNull);
  });

  test('characterProvider save is observable on a subsequent read of characterProvider(id)', () async {
    final container = makeContainer();
    await db.insertCharacter(character('a', 'Original'));
    await container.read(characterProvider('a').future);

    await container
        .read(characterProvider('a').notifier)
        .save(character('a', 'Renamed'));

    final result = await container.read(characterProvider('a').future);
    expect(result?.name, 'Renamed');
  });

  test('characterProvider save invalidates characterListProvider (anti-stale regression)', () async {
    final container = makeContainer();
    await db.insertCharacter(character('a', 'Original'));
    await container.read(characterListProvider.future);

    await container
        .read(characterProvider('a').notifier)
        .save(character('a', 'Renamed'));

    final list = await container.read(characterListProvider.future);
    expect(list.single.name, 'Renamed');
  });
}
