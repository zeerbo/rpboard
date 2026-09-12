import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';

import '../support/in_memory_database.dart';

/// Pure, no-I/O tests for the `Database` seam's two new methods
/// (`exportSnapshot`/`importSnapshot`), exercised entirely against
/// [InMemoryDatabase] — no real SQLite, no widget pump. Prior art:
/// `test/providers/character_provider_test.dart`.
void main() {
  late InMemoryDatabase db;

  setUp(() => db = InMemoryDatabase());

  test('export then import against the in-memory fake preserves every '
      'Character field', () async {
    final original = Character(
      id: 'c1',
      name: 'Aria',
      race: 'Elfa',
      level: 5,
      hpMax: 40,
      hpCurrent: 30,
      spellSlots: [SpellSlot(level: 1, total: 3, used: 1)],
      spells: [Spell(name: 'Dardo Incantato', level: 1, prepared: true)],
      equipment: [
        EquipmentItem(name: 'Anello', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.ac, value: 1),
        ])
      ],
    );
    await db.insertCharacter(original);

    final snapshot = await db.exportSnapshot();
    await db.importSnapshot(snapshot);

    final roundTripped = await db.getCharacter('c1');
    expect(roundTripped, isNotNull);
    expect(roundTripped!.toMap(), original.toMap());
  });

  test('exportSnapshot reads every character, sorted name ASC like '
      'getCharacters', () async {
    await db.insertCharacter(Character(id: 'a', name: 'Gandalf'));
    await db.insertCharacter(Character(id: 'b', name: 'Aragorn'));
    await db.insertCharacter(Character(id: 'c', name: 'Boromir'));

    final snapshot = await db.exportSnapshot();

    expect(snapshot.characters.map((c) => c.id), ['b', 'c', 'a']);
  });

  test('importing into a fake holding different Characters leaves exactly '
      'the archive\'s content — nothing of the previous state survives', () async {
    await db.insertCharacter(Character(id: 'old-1', name: 'Will be replaced'));
    await db.insertCharacter(Character(id: 'old-2', name: 'Also replaced'));

    final archive = AppSnapshot(characters: [
      Character(id: 'new-1', name: 'From the archive'),
    ]);
    await db.importSnapshot(archive);

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), ['new-1']);
    expect(await db.getCharacter('old-1'), isNull);
    expect(await db.getCharacter('old-2'), isNull);
  });

  test('importing an empty archive leaves the store empty (replace, not a '
      'no-op)', () async {
    await db.insertCharacter(Character(id: 'old', name: 'Gone'));

    await db.importSnapshot(const AppSnapshot(characters: []));

    expect(await db.getCharacters(), isEmpty);
  });
}
