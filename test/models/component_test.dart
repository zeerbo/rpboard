import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/models/component.dart';

void main() {
  group('ComponentData.fromDb', () {
    test('round-trips narrativeText', () {
      final json = jsonEncode({'title': 'Prologue', 'content': 'Long ago...', 'isSecret': false});

      final data = ComponentData.fromDb('narrativeText', json) as NarrativeTextData;

      expect(data.title, 'Prologue');
      expect(data.content, 'Long ago...');
      expect(data.isSecret, false);
      expect(jsonDecode(data.toJson()), jsonDecode(json));
      expect(data.dbKey, 'narrativeText');
    });

    test('round-trips npcStatBlock', () {
      final json = jsonEncode({
        'name': 'Goblin',
        'size': 'Piccolo',
        'type': 'Umanoide',
        'alignment': 'Neutrale Malvagio',
        'ac': 15,
        'acType': 'armatura di cuoio, scudo',
        'hp': '7 (2d6)',
        'speed': '9 m',
        'str': 8,
        'dex': 14,
        'con': 10,
        'int': 10,
        'wis': 8,
        'cha': 8,
        'savingThrows': '',
        'skills': 'Furtività +6',
        'damageResistances': '',
        'damageImmunities': '',
        'conditionImmunities': '',
        'senses': 'Scurovisione 18 m, Percezione passiva 9',
        'languages': 'Comune, Goblin',
        'cr': '1/4',
        'xp': 50,
        'traits': [],
        'actions': [
          {'name': 'Scimitarra', 'desc': '4 (1d6+1) danni taglienti'}
        ],
        'bonusActions': [],
        'reactions': [],
        'legendaryActions': [],
        'notes': '',
      });

      final data = ComponentData.fromDb('npcStatBlock', json) as NpcStatBlockData;

      expect(data.name, 'Goblin');
      expect(data.ac, 15);
      expect(data.actions, [
        {'name': 'Scimitarra', 'desc': '4 (1d6+1) danni taglienti'}
      ]);
      expect(jsonDecode(data.toJson()), jsonDecode(json));
      expect(data.dbKey, 'npcStatBlock');
    });

    test('round-trips initiativeTracker', () {
      final json = jsonEncode({
        'combatants': [
          {'name': 'Aragorn', 'initiative': 18, 'hp': 45},
          {'name': 'Goblin', 'initiative': 9, 'hp': 7},
        ],
        'round': 3,
        'currentTurn': 1,
      });

      final data = ComponentData.fromDb('initiativeTracker', json) as InitiativeTrackerData;

      expect(data.round, 3);
      expect(data.currentTurn, 1);
      expect(data.combatants, [
        {'name': 'Aragorn', 'initiative': 18, 'hp': 45},
        {'name': 'Goblin', 'initiative': 9, 'hp': 7},
      ]);
      expect(jsonDecode(data.toJson()), jsonDecode(json));
      expect(data.dbKey, 'initiativeTracker');
    });

    test('round-trips customTable', () {
      final json = jsonEncode({
        'title': 'Bottino',
        'headers': ['Oggetto', 'Quantità'],
        'rows': [
          ['Spada corta', '1'],
          ['Pozione', '3'],
        ],
      });

      final data = ComponentData.fromDb('customTable', json) as CustomTableData;

      expect(data.title, 'Bottino');
      expect(data.headers, ['Oggetto', 'Quantità']);
      expect(data.rows, [
        ['Spada corta', '1'],
        ['Pozione', '3'],
      ]);
      expect(jsonDecode(data.toJson()), jsonDecode(json));
      expect(data.dbKey, 'customTable');
    });

    test('round-trips image', () {
      final json = jsonEncode({
        'title': 'Mappa',
        'path': '/images/map.png',
        'caption': 'La città di Waterdeep',
      });

      final data = ComponentData.fromDb('image', json) as ImageData;

      expect(data.title, 'Mappa');
      expect(data.path, '/images/map.png');
      expect(data.caption, 'La città di Waterdeep');
      expect(jsonDecode(data.toJson()), jsonDecode(json));
      expect(data.dbKey, 'image');
    });

    test('falls back to UnknownComponentData for an unrecognized type', () {
      final json = jsonEncode({'somethingFromANewerBuild': true});

      final data = ComponentData.fromDb('futureComponentKind', json) as UnknownComponentData;

      expect(data.dbKey, 'futureComponentKind');
      expect(data.toJson(), json);
    });
  });
}
