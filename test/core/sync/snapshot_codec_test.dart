import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/models/campaign.dart';
import 'package:rpboard/models/chapter.dart';
import 'package:rpboard/models/session_screen.dart';
import 'package:rpboard/models/component.dart';

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

  group('Campaign material round trip', () {
    // One of every ComponentData kind, including the unknown-kind shape
    // ADR-0001 preserves for an unrecognized or malformed payload.
    SessionComponent componentOf(String id, int order, ComponentData data) =>
        SessionComponent(id: id, screenId: 's1', order: order, data: data);

    final componentsOfEveryKind = [
      componentOf('comp-narrative', 0, NarrativeTextData(
        title: 'Prologo',
        content: 'Molto tempo fa...',
        isSecret: true,
      )),
      componentOf('comp-npc', 1, NpcStatBlockData(
        name: 'Goblin',
        size: 'Piccolo',
        type: 'Umanoide',
        alignment: 'Neutrale Malvagio',
        ac: 15,
        acType: 'armatura di cuoio',
        hp: '7 (2d6)',
        speed: '9 m',
        str: 8,
        dex: 14,
        con: 10,
        int_: 10,
        wis: 8,
        cha: 8,
        savingThrows: '',
        skills: 'Furtività +6',
        damageResistances: '',
        damageImmunities: '',
        conditionImmunities: '',
        senses: 'Scurovisione 18 m',
        languages: 'Comune',
        cr: '1/4',
        xp: 50,
        traits: [{'name': 'Astuzia nemica'}],
        actions: [{'name': 'Pugnale'}],
        bonusActions: [],
        reactions: [],
        legendaryActions: [],
        notes: 'Codardo',
      )),
      componentOf('comp-initiative', 2, InitiativeTrackerData(
        combatants: [
          {'name': 'Goblin', 'initiative': 15},
          {'name': 'Aria', 'initiative': 12},
        ],
        round: 2,
        currentTurn: 1,
      )),
      componentOf('comp-table', 3, CustomTableData(
        title: 'Bottino casuale',
        headers: ['d6', 'Oggetto'],
        rows: [
          ['1', 'Moneta antica'],
          ['2', 'Pugnale arrugginito'],
        ],
      )),
      componentOf('comp-image', 4, ImageData(
        title: 'Mappa',
        path: 'assets/images/map.png',
        caption: 'La foresta oscura',
      )),
      componentOf('comp-unknown', 5, UnknownComponentData(
        rawType: 'futureComponentKind',
        rawJson: '{"someField":"someValue"}',
      )),
    ];

    Campaign campaignOf(String id) => Campaign(
          id: id,
          name: 'La maledizione di Strahd',
          description: 'Una campagna gotica',
          setting: 'Barovia',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 2, 1),
        );

    test('a snapshot with every aggregate survives the round trip with '
        'nothing lost and no field altered', () {
      final campaign = campaignOf('camp1');
      final chapters = [
        Chapter(id: 'ch1', campaignId: 'camp1', title: 'Capitolo I', summary: 'Inizio', order: 0),
        Chapter(id: 'ch2', campaignId: 'camp1', title: 'Capitolo II', summary: 'Seguito', order: 1),
      ];
      final screens = [
        SessionScreen(id: 's1', chapterId: 'ch1', title: 'Scena A', order: 0),
        SessionScreen(id: 's2', chapterId: 'ch1', title: 'Scena B', order: 1),
      ];

      final original = AppSnapshot(
        characters: [Character(id: 'c1', name: 'Aria')],
        campaigns: [campaign],
        chapters: chapters,
        screens: screens,
        components: componentsOfEveryKind,
      );

      final json = codec.encode(
        snapshot: original,
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: DateTime.utc(2026, 9, 12),
        deviceLabel: 'DESKTOP-TEST',
      );
      final decoded = codec.decode(json).snapshot;

      expect(decoded.campaigns.map((c) => c.toMap()).toList(),
          original.campaigns.map((c) => c.toMap()).toList());
      expect(decoded.chapters.map((c) => c.toMap()).toList(),
          original.chapters.map((c) => c.toMap()).toList());
      expect(decoded.screens.map((s) => s.toMap()).toList(),
          original.screens.map((s) => s.toMap()).toList());
      expect(decoded.components.map((c) => c.toMap()).toList(),
          original.components.map((c) => c.toMap()).toList(),
          reason: 'every ComponentData kind, including the unknown-kind '
              'shape, must round-trip with its typed payload intact');
    });

    test('each typed ComponentData payload round-trips as the same kind it '
        'was', () {
      final original = AppSnapshot(characters: const [], components: componentsOfEveryKind);
      final json = codec.encode(
        snapshot: original,
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: DateTime.utc(2026),
        deviceLabel: 'x',
      );

      final decoded = codec.decode(json).snapshot.components;
      expect(decoded, hasLength(componentsOfEveryKind.length));

      expect(decoded[0].data, isA<NarrativeTextData>());
      expect((decoded[0].data as NarrativeTextData).title, 'Prologo');

      expect(decoded[1].data, isA<NpcStatBlockData>());
      expect((decoded[1].data as NpcStatBlockData).name, 'Goblin');

      expect(decoded[2].data, isA<InitiativeTrackerData>());
      expect((decoded[2].data as InitiativeTrackerData).round, 2);

      expect(decoded[3].data, isA<CustomTableData>());
      expect((decoded[3].data as CustomTableData).headers, ['d6', 'Oggetto']);

      expect(decoded[4].data, isA<ImageData>());
      expect((decoded[4].data as ImageData).path, 'assets/images/map.png');

      expect(decoded[5].data, isA<UnknownComponentData>());
      final unknown = decoded[5].data as UnknownComponentData;
      expect(unknown.rawType, 'futureComponentKind');
      expect(unknown.rawJson, '{"someField":"someValue"}');
    });

    test('the dense, zero-based order of Chapters, SessionScreens and '
        'SessionComponents survives the round trip unchanged', () {
      final chapters = [
        Chapter(id: 'ch1', campaignId: 'camp1', order: 0),
        Chapter(id: 'ch2', campaignId: 'camp1', order: 1),
        Chapter(id: 'ch3', campaignId: 'camp1', order: 2),
      ];
      final screens = [
        SessionScreen(id: 's1', chapterId: 'ch1', order: 0),
        SessionScreen(id: 's2', chapterId: 'ch1', order: 1),
      ];
      final components = [
        componentOf('cA', 0, NarrativeTextData.empty()),
        componentOf('cB', 1, NarrativeTextData.empty()),
        componentOf('cC', 2, NarrativeTextData.empty()),
      ];

      final json = codec.encode(
        snapshot: AppSnapshot(
          characters: const [],
          chapters: chapters,
          screens: screens,
          components: components,
        ),
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: DateTime.utc(2026),
        deviceLabel: 'x',
      );
      final decoded = codec.decode(json).snapshot;

      expect(decoded.chapters.map((c) => c.order), [0, 1, 2]);
      expect(decoded.chapters.map((c) => c.id), ['ch1', 'ch2', 'ch3']);
      expect(decoded.screens.map((s) => s.order), [0, 1]);
      expect(decoded.components.map((c) => c.order), [0, 1, 2]);
    });

    test('an archive with no Campaign material (a ticket-02 archive) decodes '
        'with empty Campaign lists rather than being refused', () {
      final json = '{"formatVersion": 1, "schemaVersion": 4, '
          '"appVersion": "1.0.0", "exportedAt": "2026-01-01T00:00:00.000Z", '
          '"deviceLabel": "x", "payload": {"characters": '
          '[{"id": "c1", "name": "Aria"}]}}';

      final decoded = codec.decode(json).snapshot;

      expect(decoded.characters, hasLength(1));
      expect(decoded.campaigns, isEmpty);
      expect(decoded.chapters, isEmpty);
      expect(decoded.screens, isEmpty);
      expect(decoded.components, isEmpty);
    });
  });
}
