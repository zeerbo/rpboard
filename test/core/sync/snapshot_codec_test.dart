import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';

/// Pure, no-I/O tests for [SnapshotCodec]: `AppSnapshot` <-> JSON, the
/// envelope, and malformed input. Prior art: `test/models/component_test.dart`
/// and `test/core/ordering/reorder_test.dart` — plain Dart, no database, no
/// widget pump.
void main() {
  const codec = SnapshotCodec();

  Character fullCharacter() => Character(
        id: 'c1',
        name: 'Aria Nightshade',
        playerName: 'Luca',
        race: 'Elfa',
        characterClass: 'Ranger',
        subclass: 'Cacciatrice',
        level: 5,
        background: 'Sopravvissuta',
        alignment: 'Neutrale Buono',
        experiencePoints: 6500,
        strength: 12,
        dexterity: 18,
        constitution: 14,
        intelligence: 10,
        wisdom: 16,
        charisma: 8,
        hpMax: 44,
        hpCurrent: 30,
        hpTemp: 5,
        armorClass: 14,
        initiativeBonus: 4,
        speed: 35,
        hitDice: '5d10',
        hitDiceUsed: 2,
        hasInspiration: true,
        savingThrowProfs: ['dex', 'wis'],
        skillProfs: ['Percezione', 'Furtività'],
        skillExpertise: ['Furtività'],
        deathSaveSuccesses: 1,
        deathSaveFailures: 0,
        isDead: false,
        isStable: false,
        inventory: [InventoryItem(name: 'Corda', quantity: 1, weight: 5, notes: '15m')],
        cp: 10,
        sp: 5,
        ep: 0,
        gp: 120,
        pp: 1,
        personalityTraits: 'Silenziosa',
        ideals: 'Libertà',
        bonds: 'Il suo branco',
        flaws: 'Non si fida di nessuno',
        features: [CharacterFeature(title: 'Nemico Prescelto', description: 'Umanoidi')],
        languages: ['Comune', 'Elfico'],
        backstory: 'Cresciuta nella foresta...',
        appearance: 'Capelli argento',
        age: 120,
        height: '175cm',
        weight: '60kg',
        eyes: 'Verdi',
        skin: 'Chiara',
        hair: 'Argento',
        attacks: [Attack(name: 'Arco lungo', attackBonus: '+7', damage: '1d8+4', type: 'perforante')],
        armor: Armor(name: 'Corazza di cuoio', baseAc: 12, addsDex: true),
        equipment: [
          EquipmentItem(
            name: 'Anello di protezione',
            notes: '+1 a tutto',
            bonuses: [
              EquipmentBonus(type: EquipmentBonusType.ac, value: 1),
              EquipmentBonus(
                type: EquipmentBonusType.savingThrow,
                value: 1,
                target: 'all',
              ),
            ],
          ),
        ],
        spellcastingAbility: 'Saggezza',
        preparedSpellsMax: 3,
        spellSlots: [SpellSlot(level: 1, total: 3, used: 1)],
        spells: [Spell(name: 'Individuazione del Magico', level: 1, prepared: true)],
        notes: 'Alcune note libere',
      );

  group('codec round trip', () {
    test('a snapshot serialized and read back equals the original', () {
      final original = AppSnapshot(characters: [fullCharacter()]);

      final json = codec.encode(
        snapshot: original,
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: DateTime.utc(2026, 9, 12, 10, 30),
        deviceLabel: 'DESKTOP-TEST',
      );
      final envelope = codec.decode(json);

      expect(envelope.snapshot.characters, hasLength(1));
      expect(
        envelope.snapshot.characters.single.toMap(),
        original.characters.single.toMap(),
        reason: 'every field — including typed nested payloads like armor, '
            'equipment bonuses, spells and spell slots — must survive the '
            'round trip intact',
      );
    });

    test('preserves the envelope metadata exactly', () {
      final exportedAt = DateTime.utc(2026, 9, 12, 10, 30, 15, 250);
      final json = codec.encode(
        snapshot: const AppSnapshot(characters: []),
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: exportedAt,
        deviceLabel: 'DESKTOP-TEST',
      );

      final envelope = codec.decode(json);

      expect(envelope.formatVersion, SnapshotCodec.formatVersion);
      expect(envelope.schemaVersion, 4);
      expect(envelope.appVersion, '1.0.0+1');
      expect(envelope.exportedAt, exportedAt);
      expect(envelope.deviceLabel, 'DESKTOP-TEST');
    });

    test('an empty snapshot round-trips to an empty character list', () {
      final json = codec.encode(
        snapshot: const AppSnapshot(characters: []),
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: DateTime.utc(2026),
        deviceLabel: 'x',
      );

      expect(codec.decode(json).snapshot.characters, isEmpty);
    });

    test('multiple characters keep their identity and order', () {
      final a = Character(id: 'a', name: 'Aragorn');
      final b = Character(id: 'b', name: 'Boromir');
      final json = codec.encode(
        snapshot: AppSnapshot(characters: [a, b]),
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: DateTime.utc(2026),
        deviceLabel: 'x',
      );

      final decoded = codec.decode(json).snapshot.characters;
      expect(decoded.map((c) => c.id), ['a', 'b']);
      expect(decoded.map((c) => c.name), ['Aragorn', 'Boromir']);
    });
  });

  group('malformed envelopes are refused, not partially applied', () {
    test('a string that is not JSON at all', () {
      expect(
        () => codec.decode('this is not json {{{'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('valid JSON that is not an object', () {
      expect(
        () => codec.decode('[1, 2, 3]'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('an object missing formatVersion', () {
      expect(
        () => codec.decode('{"schemaVersion": 4, "appVersion": "1.0.0", '
            '"exportedAt": "2026-01-01T00:00:00.000Z", "deviceLabel": "x", '
            '"payload": {"characters": []}}'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('formatVersion present but non-numeric', () {
      expect(
        () => codec.decode('{"formatVersion": "one", "schemaVersion": 4, '
            '"appVersion": "1.0.0", "exportedAt": "2026-01-01T00:00:00.000Z", '
            '"deviceLabel": "x", "payload": {"characters": []}}'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('schemaVersion missing', () {
      expect(
        () => codec.decode('{"formatVersion": 1, "appVersion": "1.0.0", '
            '"exportedAt": "2026-01-01T00:00:00.000Z", "deviceLabel": "x", '
            '"payload": {"characters": []}}'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('exportedAt is not a parseable date', () {
      expect(
        () => codec.decode('{"formatVersion": 1, "schemaVersion": 4, '
            '"appVersion": "1.0.0", "exportedAt": "not-a-date", '
            '"deviceLabel": "x", "payload": {"characters": []}}'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('payload missing entirely (truncated archive)', () {
      expect(
        () => codec.decode('{"formatVersion": 1, "schemaVersion": 4, '
            '"appVersion": "1.0.0", "exportedAt": "2026-01-01T00:00:00.000Z", '
            '"deviceLabel": "x"}'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('a character entry that is not an object', () {
      expect(
        () => codec.decode('{"formatVersion": 1, "schemaVersion": 4, '
            '"appVersion": "1.0.0", "exportedAt": "2026-01-01T00:00:00.000Z", '
            '"deviceLabel": "x", "payload": {"characters": ["not-an-object"]}}'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });

    test('a character missing its required id', () {
      expect(
        () => codec.decode('{"formatVersion": 1, "schemaVersion": 4, '
            '"appVersion": "1.0.0", "exportedAt": "2026-01-01T00:00:00.000Z", '
            '"deviceLabel": "x", "payload": {"characters": [{"name": "Nameless"}]}}'),
        throwsA(isA<SnapshotFormatException>()),
      );
    });
  });
}
