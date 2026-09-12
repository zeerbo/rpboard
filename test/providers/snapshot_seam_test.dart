import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/models/campaign.dart';
import 'package:rpboard/models/chapter.dart';
import 'package:rpboard/models/session_screen.dart';
import 'package:rpboard/models/component.dart';

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

  group('Campaign material', () {
    // One SessionComponent of every ComponentData kind, including the
    // unknown-kind shape ADR-0001 preserves for an unrecognized payload.
    List<SessionComponent> componentsOfEveryKind(String screenId) => [
          SessionComponent(
            id: 'comp-narrative',
            screenId: screenId,
            order: 0,
            data: NarrativeTextData(title: 'Prologo', content: 'Molto tempo fa...', isSecret: true),
          ),
          SessionComponent(
            id: 'comp-npc',
            screenId: screenId,
            order: 1,
            data: NpcStatBlockData(
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
              traits: [
                {'name': 'Astuzia nemica'}
              ],
              actions: [
                {'name': 'Pugnale'}
              ],
              bonusActions: const [],
              reactions: const [],
              legendaryActions: const [],
              notes: 'Codardo',
            ),
          ),
          SessionComponent(
            id: 'comp-initiative',
            screenId: screenId,
            order: 2,
            data: InitiativeTrackerData(
              combatants: [
                {'name': 'Goblin', 'initiative': 15},
              ],
              round: 2,
              currentTurn: 1,
            ),
          ),
          SessionComponent(
            id: 'comp-table',
            screenId: screenId,
            order: 3,
            data: CustomTableData(
              title: 'Bottino casuale',
              headers: ['d6', 'Oggetto'],
              rows: [
                ['1', 'Moneta antica']
              ],
            ),
          ),
          SessionComponent(
            id: 'comp-image',
            screenId: screenId,
            order: 4,
            data: ImageData(title: 'Mappa', path: 'assets/images/map.png', caption: 'La foresta oscura'),
          ),
          SessionComponent(
            id: 'comp-unknown',
            screenId: screenId,
            order: 5,
            data: UnknownComponentData(rawType: 'futureComponentKind', rawJson: '{"someField":"someValue"}'),
          ),
        ];

    /// The mechanical guard against silent data loss the ticket names: a
    /// snapshot populated with every aggregate — Characters, Campaigns,
    /// Chapters, SessionScreens, and a SessionComponent of every
    /// `ComponentData` kind — must survive export then import with nothing
    /// lost and no field altered. A future table left out of `AppSnapshot`
    /// (or out of `exportSnapshot`/`importSnapshot`) turns this test red.
    test('a snapshot populated with every aggregate survives export then '
        'import with nothing lost and no field altered', () async {
      final character = Character(id: 'c1', name: 'Aria', race: 'Elfa');
      final campaign = Campaign(
        id: 'camp1',
        name: 'La maledizione di Strahd',
        description: 'Una campagna gotica',
        setting: 'Barovia',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      );
      final chapter = Chapter(id: 'ch1', campaignId: 'camp1', title: 'Capitolo I', summary: 'Inizio', order: 0);
      final screen = SessionScreen(id: 's1', chapterId: 'ch1', title: 'Scena A', order: 0);
      final components = componentsOfEveryKind('s1');

      await db.insertCharacter(character);
      await db.insertCampaign(campaign);
      await db.insertChapter(chapter);
      await db.insertScreen(screen);
      for (final c in components) {
        await db.insertComponent(c);
      }

      final snapshot = await db.exportSnapshot();

      expect(snapshot.characters, hasLength(1));
      expect(snapshot.campaigns, hasLength(1));
      expect(snapshot.chapters, hasLength(1));
      expect(snapshot.screens, hasLength(1));
      expect(snapshot.components, hasLength(components.length));

      final destination = InMemoryDatabase();
      await destination.importSnapshot(snapshot);

      expect((await destination.getCharacter('c1'))!.toMap(), character.toMap());
      expect((await destination.getCampaign('camp1'))!.toMap(), campaign.toMap());
      expect((await destination.getChapter('ch1'))!.toMap(), chapter.toMap());
      expect((await destination.getScreen('s1'))!.toMap(), screen.toMap());

      final importedComponents = await destination.getComponents('s1');
      expect(importedComponents.map((c) => c.toMap()).toList(),
          components.map((c) => c.toMap()).toList(),
          reason: 'every ComponentData kind, including the unknown-kind '
              'shape, must survive the round trip with its typed payload '
              'intact');
    });

    test('exportSnapshot reaches Chapters, SessionScreens and '
        'SessionComponents only by descending from a Campaign, so an orphan '
        'row is not exported', () async {
      // No campaign exists for this chapter at all — an orphan, as described
      // by the foreign-keys-not-enforced defect this feature deliberately
      // does not try to fix.
      await db.insertCampaign(Campaign(
        id: 'camp1',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ));
      await db.insertChapter(Chapter(id: 'orphan-ch', campaignId: 'does-not-exist', order: 0));

      final snapshot = await db.exportSnapshot();

      expect(snapshot.chapters, isEmpty);
    });

    test('the dense, zero-based order of Chapters, SessionScreens and '
        'SessionComponents is identical after the round trip', () async {
      await db.insertCampaign(Campaign(id: 'camp1', createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026)));
      final chapters = [
        Chapter(id: 'ch1', campaignId: 'camp1', order: 0),
        Chapter(id: 'ch2', campaignId: 'camp1', order: 1),
        Chapter(id: 'ch3', campaignId: 'camp1', order: 2),
      ];
      for (final c in chapters) {
        await db.insertChapter(c);
      }
      final screens = [
        SessionScreen(id: 's1', chapterId: 'ch1', order: 0),
        SessionScreen(id: 's2', chapterId: 'ch1', order: 1),
      ];
      for (final s in screens) {
        await db.insertScreen(s);
      }
      final components = [
        SessionComponent(id: 'cA', screenId: 's1', order: 0, data: NarrativeTextData.empty()),
        SessionComponent(id: 'cB', screenId: 's1', order: 1, data: NarrativeTextData.empty()),
        SessionComponent(id: 'cC', screenId: 's1', order: 2, data: NarrativeTextData.empty()),
      ];
      for (final c in components) {
        await db.insertComponent(c);
      }

      final snapshot = await db.exportSnapshot();
      final destination = InMemoryDatabase();
      await destination.importSnapshot(snapshot);

      final importedChapters = await destination.getChapters('camp1');
      expect(importedChapters.map((c) => c.order), [0, 1, 2]);
      expect(importedChapters.map((c) => c.id), ['ch1', 'ch2', 'ch3']);

      final importedScreens = await destination.getScreens('ch1');
      expect(importedScreens.map((s) => s.order), [0, 1]);

      final importedComponents = await destination.getComponents('s1');
      expect(importedComponents.map((c) => c.order), [0, 1, 2]);
    });

    test('importing an archive with no Campaign material (a ticket-02 '
        'archive) still works and simply results in no Campaigns', () async {
      await db.insertCampaign(Campaign(id: 'will-be-cleared', createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026)));
      await db.insertCharacter(Character(id: 'c1', name: 'Aria'));

      // Mirrors a ticket-02 archive: only characters, no Campaign material —
      // exactly what AppSnapshot's default empty lists produce.
      final archive = AppSnapshot(characters: [Character(id: 'imported', name: 'From archive')]);

      await db.importSnapshot(archive);

      expect(await db.getCharacters(), hasLength(1));
      expect(await db.getCampaigns(), isEmpty);
    });
  });
}
