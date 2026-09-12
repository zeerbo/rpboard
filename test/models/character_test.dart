import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/models/character.dart';

Character _char({String spellcastingAbility = '', int level = 1}) => Character(
      id: 'c1',
      level: level,
      spellcastingAbility: spellcastingAbility,
    );

void main() {
  group('Character spellcasting derivation', () {
    // Table-driven over all six Italian ability names, plus dirty input.
    // proficiencyBonus at level 1 is +2 (see Character.proficiencyBonus).
    final cases = <String, int Function(Character c)>{
      'Forza': (c) => c.strMod,
      'forza': (c) => c.strMod,
      ' Forza ': (c) => c.strMod,
      'Destrezza': (c) => c.dexMod,
      'DESTREZZA': (c) => c.dexMod,
      'Costituzione': (c) => c.conMod,
      '  costituzione': (c) => c.conMod,
      'Intelligenza': (c) => c.intMod,
      'intelligenza  ': (c) => c.intMod,
      'Saggezza': (c) => c.wisMod,
      'SaGgEzZa': (c) => c.wisMod,
      'Carisma': (c) => c.chaMod,
      ' CARISMA ': (c) => c.chaMod,
    };

    cases.forEach((raw, expectedModOf) {
      test('"$raw" resolves to the correct ability modifier', () {
        final c = _char(spellcastingAbility: raw)
          ..strength = 20 // +5
          ..dexterity = 18 // +4
          ..constitution = 16 // +3
          ..intelligence = 14 // +2
          ..wisdom = 8 // -1
          ..charisma = 6; // -2

        final expectedMod = expectedModOf(c);
        expect(c.spellcastingAbilityMod, expectedMod);
        expect(c.spellSaveDC, 8 + c.proficiencyBonus + expectedMod);
        expect(c.spellAttackBonus, c.proficiencyBonus + expectedMod);
      });
    });

    for (final dirty in ['', 'Costituzion', 'nonsense', '   ', 'Carism4']) {
      test('unrecognized input "$dirty" falls back to a zero modifier', () {
        final c = _char(spellcastingAbility: dirty)
          ..charisma = 20 // would be +5 if (wrongly) matched to Carisma
          ..intelligence = 20;

        expect(c.spellcastingAbilityMod, 0);
        expect(c.spellSaveDC, 8 + c.proficiencyBonus);
        expect(c.spellAttackBonus, c.proficiencyBonus);
      });
    }
  });

  group('Character spell slots', () {
    test('setSpellSlotTotal adds a new row', () {
      final c = _char();
      c.setSpellSlotTotal(1, 4);
      expect(c.spellSlots, hasLength(1));
      expect(c.spellSlots.single.level, 1);
      expect(c.spellSlots.single.total, 4);
      expect(c.spellSlots.single.used, 0);
    });

    test('setSpellSlotTotal updates an existing row without resetting used', () {
      final c = _char();
      c.setSpellSlotTotal(1, 4);
      c.useSpellSlot(1);
      c.setSpellSlotTotal(1, 6);

      final slot = c.spellSlots.single;
      expect(slot.total, 6);
      expect(slot.used, 1);
    });

    test('setting total to 0 removes the level row', () {
      final c = _char();
      c.setSpellSlotTotal(2, 3);
      expect(c.spellSlots, hasLength(1));

      c.setSpellSlotTotal(2, 0);
      expect(c.spellSlots, isEmpty);
    });

    test('useSpellSlot is a no-op once used == total', () {
      final c = _char();
      c.setSpellSlotTotal(1, 1);
      c.useSpellSlot(1);
      expect(c.spellSlots.single.used, 1);

      c.useSpellSlot(1); // already fully used
      expect(c.spellSlots.single.used, 1);
    });

    test('useSpellSlot on a level with no row is a no-op', () {
      final c = _char();
      c.useSpellSlot(3);
      expect(c.spellSlots, isEmpty);
    });

    test('restoreSpellSlot is a no-op once used == 0', () {
      final c = _char();
      c.setSpellSlotTotal(1, 2);
      c.restoreSpellSlot(1); // already at 0
      expect(c.spellSlots.single.used, 0);
    });

    test('use then restore round-trips used back to 0', () {
      final c = _char();
      c.setSpellSlotTotal(1, 2);
      c.useSpellSlot(1);
      c.useSpellSlot(1);
      expect(c.spellSlots.single.used, 2);

      c.restoreSpellSlot(1);
      expect(c.spellSlots.single.used, 1);
      c.restoreSpellSlot(1);
      expect(c.spellSlots.single.used, 0);
    });
  });

  group('Character death saves', () {
    test('ticking success box i sets count to i+1', () {
      final c = _char();
      c.tickDeathSaveSuccess(0);
      expect(c.deathSaveSuccesses, 1);
      c.tickDeathSaveSuccess(1);
      expect(c.deathSaveSuccesses, 2);
    });

    test('ticking failure box i sets count to i+1', () {
      final c = _char();
      c.tickDeathSaveFailure(0);
      expect(c.deathSaveFailures, 1);
      c.tickDeathSaveFailure(1);
      expect(c.deathSaveFailures, 2);
    });

    test('clicking an already-ticked box undoes back down to it', () {
      final c = _char();
      c.tickDeathSaveFailure(0);
      c.tickDeathSaveFailure(1);
      expect(c.deathSaveFailures, 2);
      c.tickDeathSaveFailure(0); // click box 0 again: count was 2 (> 0) -> 0
      expect(c.deathSaveFailures, 0);
    });

    test('reaching 3 failures sets isDead and resets both counters', () {
      final c = _char();
      c.tickDeathSaveSuccess(0); // 1 success first, to prove it also resets
      c.tickDeathSaveFailure(0);
      c.tickDeathSaveFailure(1);
      expect(c.isDead, isFalse);

      c.tickDeathSaveFailure(2);

      expect(c.isDead, isTrue);
      expect(c.deathSaveFailures, 0);
      expect(c.deathSaveSuccesses, 0);
    });

    test('reaching 3 successes sets isStable and resets both counters', () {
      final c = _char();
      c.tickDeathSaveFailure(0); // 1 failure first, to prove it also resets
      c.tickDeathSaveSuccess(0);
      c.tickDeathSaveSuccess(1);
      expect(c.isStable, isFalse);

      c.tickDeathSaveSuccess(2);

      expect(c.isStable, isTrue);
      expect(c.deathSaveSuccesses, 0);
      expect(c.deathSaveFailures, 0);
    });

    test('resetDeathSaves zeroes both counters without clearing isDead/isStable', () {
      final c = _char();
      c.tickDeathSaveFailure(0);
      c.tickDeathSaveFailure(1);
      c.tickDeathSaveFailure(2); // isDead = true
      expect(c.isDead, isTrue);

      c.resetDeathSaves();

      expect(c.deathSaveSuccesses, 0);
      expect(c.deathSaveFailures, 0);
      expect(c.isDead, isTrue); // sticky
    });

    test('resetDeathSaves zeroes counters that never reached a decision', () {
      final c = _char();
      c.tickDeathSaveSuccess(0);
      c.tickDeathSaveFailure(0);

      c.resetDeathSaves();

      expect(c.deathSaveSuccesses, 0);
      expect(c.deathSaveFailures, 0);
      expect(c.isDead, isFalse);
      expect(c.isStable, isFalse);
    });

    test('clearDeathOutcome un-sets sticky isDead and zeroes counters', () {
      final c = _char();
      c.tickDeathSaveFailure(0);
      c.tickDeathSaveFailure(1);
      c.tickDeathSaveFailure(2); // isDead = true
      expect(c.isDead, isTrue);

      c.clearDeathOutcome();

      expect(c.isDead, isFalse);
      expect(c.isStable, isFalse);
      expect(c.deathSaveSuccesses, 0);
      expect(c.deathSaveFailures, 0);
    });
  });

  group('Character armorClassEffective (ticket 01)', () {
    test('armor with addsDex true adds dexMod to baseAc', () {
      final c = _char()
        ..dexterity = 16 // +3
        ..armor = Armor(name: 'Cuoio Borchiato', baseAc: 12, addsDex: true);

      expect(c.armorClassEffective, 15);
    });

    test('armor with addsDex false uses baseAc exactly, ignoring dexMod', () {
      final c = _char()
        ..dexterity = 16 // +3, must not be added
        ..armor = Armor(name: 'Placcata', baseAc: 18, addsDex: false);

      expect(c.armorClassEffective, 18);
    });

    test('no armor falls back to the manual armorClass field', () {
      final c = _char()..armorClass = 14;

      expect(c.armor, isNull);
      expect(c.armorClassEffective, 14);
    });

    test('round-trip with armor: toMap -> fromMap preserves armor and armorClassEffective', () {
      final c = _char()
        ..dexterity = 16
        ..armor = Armor(name: 'Cotta di Maglia', baseAc: 13, addsDex: true);

      final restored = Character.fromMap(c.toMap());

      expect(restored.armor, isNotNull);
      expect(restored.armor!.name, 'Cotta di Maglia');
      expect(restored.armor!.baseAc, 13);
      expect(restored.armor!.addsDex, isTrue);
      expect(restored.armorClassEffective, c.armorClassEffective);
    });

    test('round-trip without armor: toMap -> fromMap leaves armor null', () {
      final c = _char()..armorClass = 11;

      final restored = Character.fromMap(c.toMap());

      expect(restored.armor, isNull);
      expect(restored.armorClassEffective, 11);
    });

    test('legacy input with no armor key at all: fromMap yields armor null, no exception', () {
      final legacyMap = _char().toMap()..remove('armor');

      expect(() => Character.fromMap(legacyMap), returnsNormally);
      final restored = Character.fromMap(legacyMap);
      expect(restored.armor, isNull);
    });
  });

  group('Character equipment AC bonus (ticket 02)', () {
    test('an item ac bonus sums on top of armor', () {
      final c = _char()
        ..armor = Armor(name: 'Cuoio', baseAc: 14, addsDex: false)
        ..equipment.add(EquipmentItem(
          name: 'Anello di Protezione',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ac, value: 2)],
        ));

      expect(c.armorClassEffective, 16);
    });

    test('an item ac bonus sums on top of the manual armorClass when there is no armor', () {
      final c = _char()
        ..armorClass = 12
        ..equipment.add(EquipmentItem(
          name: 'Anello di Protezione',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ac, value: 2)],
        ));

      expect(c.armor, isNull);
      expect(c.armorClassEffective, 14);
    });

    test('multiple items with multiple ac bonuses are all summed', () {
      final c = _char()
        ..armorClass = 10
        ..equipment.addAll([
          EquipmentItem(name: 'Anello A', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.ac, value: 1),
            EquipmentBonus(type: EquipmentBonusType.ac, value: 1),
          ]),
          EquipmentItem(name: 'Mantello B', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.ac, value: 3),
          ]),
        ]);

      expect(c.sumEquipmentBonus(EquipmentBonusType.ac), 5);
      expect(c.armorClassEffective, 15);
    });

    test('round-trip: toMap -> fromMap preserves equipment and armorClassEffective', () {
      final c = _char()
        ..armorClass = 11
        ..equipment.add(EquipmentItem(
          name: 'Amuleto',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ac, value: 2)],
        ));

      final restored = Character.fromMap(c.toMap());

      expect(restored.equipment, hasLength(1));
      expect(restored.equipment.single.name, 'Amuleto');
      expect(restored.equipment.single.bonuses.single.type, EquipmentBonusType.ac);
      expect(restored.equipment.single.bonuses.single.value, 2);
      expect(restored.armorClassEffective, c.armorClassEffective);
    });

    test('legacy input with no equipment key at all: fromMap yields an empty list, no exception', () {
      final legacyMap = _char().toMap()..remove('equipment');

      expect(() => Character.fromMap(legacyMap), returnsNormally);
      final restored = Character.fromMap(legacyMap);
      expect(restored.equipment, isEmpty);
    });

    test('no regression: ticket-01 armor cases still hold with empty equipment', () {
      final withDex = _char()
        ..dexterity = 16
        ..armor = Armor(name: 'Cuoio Borchiato', baseAc: 12, addsDex: true);
      expect(withDex.equipment, isEmpty);
      expect(withDex.armorClassEffective, 15);

      final fixed = _char()
        ..dexterity = 16
        ..armor = Armor(name: 'Placcata', baseAc: 18, addsDex: false);
      expect(fixed.armorClassEffective, 18);

      final manual = _char()..armorClass = 14;
      expect(manual.armor, isNull);
      expect(manual.armorClassEffective, 14);
    });
  });

  group('Character attack/damage equipment bonuses (ticket 03)', () {
    test('attackWithEquipment: numeric attackBonus with one attack bonus sums to a total', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Anello di Precisione',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.attack, value: 1)],
        ));
      final attack = Attack(name: 'Spada Lunga', attackBonus: '+5');

      final result = c.attackWithEquipment(attack);

      expect(result.total, 6);
      expect(result.equip, 1);
    });

    test('attackWithEquipment: multiple attack bonuses across items are summed', () {
      final c = _char()
        ..equipment.addAll([
          EquipmentItem(name: 'Anello A', bonuses: [EquipmentBonus(type: EquipmentBonusType.attack, value: 1)]),
          EquipmentItem(name: 'Amuleto B', bonuses: [EquipmentBonus(type: EquipmentBonusType.attack, value: 2)]),
        ]);
      final attack = Attack(name: 'Arco', attackBonus: '+3');

      final result = c.attackWithEquipment(attack);

      expect(result.total, 6);
      expect(result.equip, 3);
    });

    test('attackWithEquipment: non-numeric attackBonus leaves total null but exposes the equip share', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Anello di Precisione',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.attack, value: 1)],
        ));

      final dice = c.attackWithEquipment(Attack(name: 'Strano', attackBonus: '1d6'));
      expect(dice.total, isNull);
      expect(dice.equip, 1);

      final empty = c.attackWithEquipment(Attack(name: 'Vuoto', attackBonus: ''));
      expect(empty.total, isNull);
      expect(empty.equip, 1);
    });

    test('attackWithEquipment: zero attack bonuses leaves total equal to the parsed base', () {
      final c = _char();
      final result = c.attackWithEquipment(Attack(name: 'Pugnale', attackBonus: '+4'));

      expect(result.equip, 0);
      expect(result.total, 4);
    });

    test('equipmentDamageBonus: a single fixed damage bonus sets fixed, leaves dice empty', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Guanto Infuocato',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.damage, value: 1, damageForm: EquipmentDamageForm.fixed)],
        ));

      final agg = c.equipmentDamageBonus();

      expect(agg.fixed, 1);
      expect(agg.dice, isEmpty);
    });

    test('equipmentDamageBonus: a single dice damage bonus lists the term, fixed stays 0', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Lama Fiammeggiante',
          bonuses: [
            EquipmentBonus(
              type: EquipmentBonusType.damage,
              damageForm: EquipmentDamageForm.dice,
              diceCount: 3,
              die: 8,
            ),
          ],
        ));

      final agg = c.equipmentDamageBonus();

      expect(agg.fixed, 0);
      expect(agg.dice, hasLength(1));
      expect(agg.dice.single.count, 3);
      expect(agg.dice.single.die, 8);
    });

    test('equipmentDamageBonus: multiple mixed damage bonuses sum fixed and list every dice term', () {
      final c = _char()
        ..equipment.addAll([
          EquipmentItem(name: 'Anello A', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.damage, value: 1, damageForm: EquipmentDamageForm.fixed),
            EquipmentBonus(type: EquipmentBonusType.damage, value: 2, damageForm: EquipmentDamageForm.fixed),
          ]),
          EquipmentItem(name: 'Lama B', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.damage, damageForm: EquipmentDamageForm.dice, diceCount: 3, die: 8),
            EquipmentBonus(type: EquipmentBonusType.damage, damageForm: EquipmentDamageForm.dice, diceCount: 1, die: 6),
          ]),
        ]);

      final agg = c.equipmentDamageBonus();

      expect(agg.fixed, 3);
      expect(agg.dice, hasLength(2));
      expect(agg.dice[0].count, 3);
      expect(agg.dice[0].die, 8);
      expect(agg.dice[1].count, 1);
      expect(agg.dice[1].die, 6);
    });

    test('equipmentDamageLabel: null when there are no damage bonuses', () {
      final c = _char();
      expect(c.equipmentDamageLabel(), isNull);
    });

    test('equipmentDamageLabel: fixed-only formats as a signed integer', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Guanto',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.damage, value: 1, damageForm: EquipmentDamageForm.fixed)],
        ));
      expect(c.equipmentDamageLabel(), '+1');
    });

    test('equipmentDamageLabel: dice-only formats as +NdM', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Lama',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.damage, damageForm: EquipmentDamageForm.dice, diceCount: 3, die: 8)],
        ));
      expect(c.equipmentDamageLabel(), '+3d8');
    });

    test('equipmentDamageLabel: mixed fixed and dice puts fixed first', () {
      final c = _char()
        ..equipment.addAll([
          EquipmentItem(name: 'Guanto', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.damage, value: 1, damageForm: EquipmentDamageForm.fixed),
          ]),
          EquipmentItem(name: 'Lama', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.damage, damageForm: EquipmentDamageForm.dice, diceCount: 3, die: 8),
          ]),
        ]);
      expect(c.equipmentDamageLabel(), '+1 +3d8');
    });

    test('round-trip: toMap -> fromMap preserves attack and damage bonuses and helper results', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Spada Incantata',
          bonuses: [
            EquipmentBonus(type: EquipmentBonusType.attack, value: 2),
            EquipmentBonus(type: EquipmentBonusType.damage, damageForm: EquipmentDamageForm.dice, diceCount: 2, die: 6),
          ],
        ));
      final attack = Attack(name: 'Spada Incantata', attackBonus: '+5', damage: '1d8+3');

      final restored = Character.fromMap(c.toMap());

      expect(restored.attackWithEquipment(attack), c.attackWithEquipment(attack));
      // Records with a List field aren't deep-equal via ==, so compare the
      // aggregator's parts explicitly.
      final restoredAgg = restored.equipmentDamageBonus();
      final originalAgg = c.equipmentDamageBonus();
      expect(restoredAgg.fixed, originalAgg.fixed);
      expect(restoredAgg.dice, originalAgg.dice);
      expect(restored.equipmentDamageLabel(), c.equipmentDamageLabel());
      expect(restored.equipmentDamageLabel(), '+2d6');
    });

    test('no regression: without attack/damage bonuses, totals equal the parsed base and label is null', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Anello di Protezione',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ac, value: 2)],
        ));
      final attack = Attack(name: 'Ascia', attackBonus: '+7');

      final result = c.attackWithEquipment(attack);
      expect(result.total, 7);
      expect(result.equip, 0);
      expect(c.equipmentDamageLabel(), isNull);
    });
  });

  group('Character initiative/speed equipment bonuses (ticket 04)', () {
    test('initiativeEffective: nude initiativeBonus plus one initiative bonus', () {
      final c = _char()
        ..initiativeBonus = 2
        ..equipment.add(EquipmentItem(
          name: 'Cappa della Prontezza',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.initiative, value: 3)],
        ));

      expect(c.initiativeEffective, 5);
    });

    test('initiativeEffective: multiple initiative bonuses across items are summed', () {
      final c = _char()
        ..initiativeBonus = 1
        ..equipment.addAll([
          EquipmentItem(name: 'Anello A', bonuses: [EquipmentBonus(type: EquipmentBonusType.initiative, value: 1)]),
          EquipmentItem(name: 'Amuleto B', bonuses: [EquipmentBonus(type: EquipmentBonusType.initiative, value: 2)]),
        ]);

      expect(c.initiativeEffective, 4);
    });

    test('initiativeEffective: no bonus equals the nude value', () {
      final c = _char()..initiativeBonus = 3;
      expect(c.initiativeEffective, 3);
    });

    test('speedEffective: nude speed plus a speed bonus', () {
      final c = _char()
        ..speed = 30
        ..equipment.add(EquipmentItem(
          name: 'Stivali Alati',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.speed, value: 3)],
        ));

      expect(c.speedEffective, 33);
    });

    test('speedEffective: no bonus equals the nude value', () {
      final c = _char()..speed = 30;
      expect(c.speedEffective, 30);
    });

    test('equipmentBadge: returns base/effective/equip when they differ', () {
      final c = _char();
      final badge = c.equipmentBadge(30, 33);

      expect(badge.base, 30);
      expect(badge.effective, 33);
      expect(badge.equip, 3);
    });

    test('equipmentBadge: equip is 0 when base equals effective', () {
      final c = _char();
      final badge = c.equipmentBadge(10, 10);

      expect(badge.equip, 0);
    });

    test('equipmentBadge: supports a negative equip share', () {
      final c = _char();
      final badge = c.equipmentBadge(30, 27);

      expect(badge.base, 30);
      expect(badge.effective, 27);
      expect(badge.equip, -3);
    });

    test('round-trip: an item with initiative and speed bonuses survives toMap/fromMap', () {
      final c = _char()
        ..initiativeBonus = 1
        ..speed = 30
        ..equipment.add(EquipmentItem(
          name: 'Stivali Alati',
          bonuses: [
            EquipmentBonus(type: EquipmentBonusType.initiative, value: 2),
            EquipmentBonus(type: EquipmentBonusType.speed, value: 10),
          ],
        ));

      final restored = Character.fromMap(c.toMap());

      expect(restored.equipment.single.bonuses, hasLength(2));
      expect(restored.initiativeEffective, c.initiativeEffective);
      expect(restored.speedEffective, c.speedEffective);
      expect(restored.initiativeEffective, 3);
      expect(restored.speedEffective, 40);
    });

    test('no regression: no init/speed bonuses leaves effective equal to nude', () {
      final c = _char()
        ..initiativeBonus = 2
        ..speed = 25
        ..equipment.add(EquipmentItem(
          name: 'Anello di Protezione',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ac, value: 2)],
        ));

      expect(c.initiativeEffective, 2);
      expect(c.speedEffective, 25);
    });
  });

  group('Character ability/savingThrow equipment bonuses + propagation (ticket 05)', () {
    test('ability bonus targeting a specific score propagates to mod, skill, save, spellcasting', () {
      final c = _char(spellcastingAbility: 'Forza')
        ..strength = 14 // nude +2
        ..skillProfs.add('Atletica') // str-based skill
        ..savingThrowProfs.add('str')
        ..equipment.add(EquipmentItem(
          name: 'Guanti del Gigante',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ability, value: 2, target: 'str')],
        ));

      expect(c.strength, 14); // nude unchanged
      expect(c.effectiveStrength, 16);
      expect(c.strMod, 3); // mod(16)
      expect(c.skillBonus('Atletica'), 3 + c.proficiencyBonus);
      expect(c.savingThrowBonus('str'), 3 + c.proficiencyBonus);
      expect(c.spellSaveDC, 8 + c.proficiencyBonus + 3);
      expect(c.spellAttackBonus, c.proficiencyBonus + 3);

      // The nude-only bases exclude equipment, so the badge deltas are the
      // true equip share for both the save and the skill.
      expect(c.savingThrowBonusBase('str'), 2 + c.proficiencyBonus); // mod(14)
      expect(c.savingThrowBonus('str') - c.savingThrowBonusBase('str'), 1);
      expect(c.skillBonusBase('Atletica'), 2 + c.proficiencyBonus);
      expect(c.skillBonus('Atletica') - c.skillBonusBase('Atletica'), 1);

      // Other scores/mods are untouched.
      expect(c.effectiveDexterity, c.dexterity);
    });

    test('ability bonus targeting "all" applies to every effective score', () {
      final c = _char()
        ..strength = 10
        ..dexterity = 10
        ..constitution = 10
        ..intelligence = 10
        ..wisdom = 10
        ..charisma = 10
        ..equipment.add(EquipmentItem(
          name: 'Manto Universale',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ability, value: 1, target: 'all')],
        ));

      expect(c.effectiveStrength, 11);
      expect(c.effectiveDexterity, 11);
      expect(c.effectiveConstitution, 11);
      expect(c.effectiveIntelligence, 11);
      expect(c.effectiveWisdom, 11);
      expect(c.effectiveCharisma, 11);
      expect(c.strMod, c.mod(11));
      expect(c.chaMod, c.mod(11));
    });

    test('savingThrow bonus targeted at one ability adds only to that save', () {
      final c = _char()
        ..dexterity = 12
        ..equipment.add(EquipmentItem(
          name: 'Anello di Riflessi',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.savingThrow, value: 1, target: 'dex')],
        ));

      final baseDex = c.savingThrowBonusBase('dex');
      final baseStr = c.savingThrowBonusBase('str');

      expect(c.savingThrowBonus('dex'), baseDex + 1);
      expect(c.savingThrowBonus('str'), baseStr); // untouched
    });

    test('savingThrow bonus targeted "all" adds to every save', () {
      final c = _char()
        ..equipment.add(EquipmentItem(
          name: 'Talismano di Resilienza',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.savingThrow, value: 2, target: 'all')],
        ));

      for (final a in ['str', 'dex', 'con', 'int', 'wis', 'cha']) {
        expect(c.savingThrowBonus(a), c.savingThrowBonusBase(a) + 2, reason: a);
      }
    });

    test('ability bonus and savingThrow bonus on the same ability stack', () {
      final c = _char()
        ..constitution = 14 // nude +2
        ..savingThrowProfs.add('con')
        ..equipment.add(EquipmentItem(
          name: 'Cintura del Vigore',
          bonuses: [
            EquipmentBonus(type: EquipmentBonusType.ability, value: 2, target: 'con'), // -> 16, mod +3
            EquipmentBonus(type: EquipmentBonusType.savingThrow, value: 1, target: 'con'),
          ],
        ));

      // Base (nude, no equipment at all): mod(14) + prof = 2 + prof
      expect(c.savingThrowBonusBase('con'), 2 + c.proficiencyBonus);
      // Effective: propagated ability score (mod 16 = +3) + prof, plus the
      // targeted savingThrow bonus on top.
      expect(c.savingThrowBonus('con'), 3 + c.proficiencyBonus + 1);
      // Equip share is the combination of both bonus sources.
      expect(c.savingThrowBonus('con') - c.savingThrowBonusBase('con'), 2);
    });

    test('savingThrowBonusBase excludes equipment entirely', () {
      final c = _char()
        ..wisdom = 16 // nude +3
        ..savingThrowProfs.add('wis')
        ..equipment.add(EquipmentItem(
          name: 'Amuleto',
          bonuses: [
            EquipmentBonus(type: EquipmentBonusType.ability, value: 4, target: 'wis'),
            EquipmentBonus(type: EquipmentBonusType.savingThrow, value: 3, target: 'wis'),
          ],
        ));

      expect(c.savingThrowBonusBase('wis'), 3 + c.proficiencyBonus);
      expect(c.savingThrowBonus('wis'), c.mod(20) + c.proficiencyBonus + 3);
    });

    test('round-trip: item with ability (target) + savingThrow (target all) bonuses survives toMap/fromMap', () {
      final c = _char()
        ..strength = 12
        ..equipment.add(EquipmentItem(
          name: 'Reliquia',
          bonuses: [
            EquipmentBonus(type: EquipmentBonusType.ability, value: 2, target: 'str'),
            EquipmentBonus(type: EquipmentBonusType.savingThrow, value: 1, target: 'all'),
          ],
        ));

      final restored = Character.fromMap(c.toMap());

      expect(restored.equipment.single.bonuses, hasLength(2));
      expect(restored.equipment.single.bonuses[0].target, 'str');
      expect(restored.equipment.single.bonuses[1].target, 'all');
      expect(restored.effectiveStrength, c.effectiveStrength);
      expect(restored.strMod, c.strMod);
      expect(restored.savingThrowBonus('str'), c.savingThrowBonus('str'));
      expect(restored.savingThrowBonus('dex'), c.savingThrowBonus('dex'));
    });

    test('no regression: no ability/savingThrow bonuses leaves every effective value equal to the nude-derived value', () {
      final c = _char(spellcastingAbility: 'Saggezza')
        ..strength = 14
        ..dexterity = 16
        ..constitution = 12
        ..intelligence = 10
        ..wisdom = 18
        ..charisma = 8
        ..savingThrowProfs.addAll(['wis', 'con'])
        ..skillProfs.add('Percezione')
        ..equipment.add(EquipmentItem(
          name: 'Anello di Protezione',
          bonuses: [EquipmentBonus(type: EquipmentBonusType.ac, value: 2)],
        ));

      expect(c.effectiveStrength, c.strength);
      expect(c.effectiveDexterity, c.dexterity);
      expect(c.effectiveConstitution, c.constitution);
      expect(c.effectiveIntelligence, c.intelligence);
      expect(c.effectiveWisdom, c.wisdom);
      expect(c.effectiveCharisma, c.charisma);

      for (final a in ['str', 'dex', 'con', 'int', 'wis', 'cha']) {
        expect(c.savingThrowBonus(a), c.savingThrowBonusBase(a), reason: a);
      }
      expect(c.skillBonus('Percezione'), c.wisMod + c.proficiencyBonus);
      expect(c.spellSaveDC, 8 + c.proficiencyBonus + c.wisMod);
      expect(c.spellAttackBonus, c.proficiencyBonus + c.wisMod);
    });
  });

  group('Spell damage field (ticket 05)', () {
    test('round-trip: toMap -> fromMap preserves Spell.damage', () {
      final c = _char()
        ..spells.add(Spell(name: 'Palla di Fuoco', level: 3, school: 'Evocazione', damage: '8d6 fuoco'));
      final restored = Character.fromMap(c.toMap());
      expect(restored.spells.single.damage, '8d6 fuoco');
    });

    test('legacy spell JSON without a damage key loads to default "" with no exception', () {
      final c = _char()..spells.add(Spell(name: 'Dardo Incantato', level: 1));
      final map = c.toMap();
      // Simulate an older payload: strip the damage key from each serialized spell.
      final spellsJson = (jsonDecode(map['spells'] as String) as List)
          .map((s) => (s as Map<String, dynamic>)..remove('damage'))
          .toList();
      map['spells'] = jsonEncode(spellsJson);
      expect(() => Character.fromMap(map), returnsNormally);
      final restored = Character.fromMap(map);
      expect(restored.spells.single.damage, '');
    });
  });

  group('EquipmentItem notes field (ticket 02)', () {
    test('round-trip: toMap -> fromMap preserves EquipmentItem.notes', () {
      final c = _char()
        ..equipment.add(EquipmentItem(name: 'Anello', notes: 'sintonizzato'));
      final restored = Character.fromMap(c.toMap());
      expect(restored.equipment.single.notes, 'sintonizzato');
    });

    test('legacy item JSON without a notes key loads to default "" with no exception', () {
      final c = _char()..equipment.add(EquipmentItem(name: 'Mantello'));
      final map = c.toMap();
      final eqJson = (jsonDecode(map['equipment'] as String) as List)
          .map((e) => (e as Map<String, dynamic>)..remove('notes'))
          .toList();
      map['equipment'] = jsonEncode(eqJson);
      expect(() => Character.fromMap(map), returnsNormally);
      final restored = Character.fromMap(map);
      expect(restored.equipment.single.notes, '');
    });
  });

  group('Character spell DC/attack equipment bonuses (ticket 03)', () {
    test('spellSaveDC includes a spellSaveDC equipment bonus over the base', () {
      final base = _char(spellcastingAbility: 'Intelligenza').spellSaveDC;
      final c = _char(spellcastingAbility: 'Intelligenza')
        ..equipment.add(EquipmentItem(name: 'Bacchetta', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.spellSaveDC, value: 2),
        ]));
      expect(c.spellSaveDC, base + 2);
    });

    test('spellAttackBonus includes a spellAttack equipment bonus over the base', () {
      final base = _char(spellcastingAbility: 'Intelligenza').spellAttackBonus;
      final c = _char(spellcastingAbility: 'Intelligenza')
        ..equipment.add(EquipmentItem(name: 'Focus', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.spellAttack, value: 3),
        ]));
      expect(c.spellAttackBonus, base + 3);
    });

    test('round-trip: spellSaveDC and spellAttack bonuses survive toMap/fromMap', () {
      final c = _char(spellcastingAbility: 'Intelligenza')
        ..equipment.add(EquipmentItem(name: 'Bastone', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.spellSaveDC, value: 1),
          EquipmentBonus(type: EquipmentBonusType.spellAttack, value: 2),
        ]));
      final restored = Character.fromMap(c.toMap());
      expect(restored.spellSaveDC, c.spellSaveDC);
      expect(restored.spellAttackBonus, c.spellAttackBonus);
      expect(restored.equipment.single.bonuses[0].type, EquipmentBonusType.spellSaveDC);
      expect(restored.equipment.single.bonuses[1].type, EquipmentBonusType.spellAttack);
    });

    test('legacy bonus with an unknown type name falls back to ac, no exception', () {
      final c = _char()
        ..equipment.add(EquipmentItem(name: 'X', bonuses: [EquipmentBonus(type: EquipmentBonusType.ac, value: 2)]));
      final map = c.toMap();
      final eqJson = (jsonDecode(map['equipment'] as String) as List).map((e) {
        final item = e as Map<String, dynamic>;
        for (final b in (item['bonuses'] as List)) {
          (b as Map<String, dynamic>)['type'] = 'totallyUnknownType';
        }
        return item;
      }).toList();
      map['equipment'] = jsonEncode(eqJson);
      expect(() => Character.fromMap(map), returnsNormally);
      final restored = Character.fromMap(map);
      expect(restored.equipment.single.bonuses.single.type, EquipmentBonusType.ac);
    });
  });

  group('Character spellDamage equipment bonus (ticket 04)', () {
    test('spellDamageLabel: null when there are no spellDamage bonuses', () {
      final c = _char()
        ..equipment.add(EquipmentItem(name: 'Anello', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.spellSaveDC, value: 2),
        ]));
      expect(c.spellDamageLabel(), isNull);
    });

    test('spellDamageLabel: fixed-only formats as a signed integer', () {
      final c = _char()
        ..equipment.add(EquipmentItem(name: 'Guanto', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.spellDamage, value: 2, damageForm: EquipmentDamageForm.fixed),
        ]));
      expect(c.spellDamageLabel(), '+2');
    });

    test('spellDamageLabel: dice-only formats as +NdM', () {
      final c = _char()
        ..equipment.add(EquipmentItem(name: 'Bastone', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.spellDamage, damageForm: EquipmentDamageForm.dice, diceCount: 1, die: 6),
        ]));
      expect(c.spellDamageLabel(), '+1d6');
    });

    test('spellDamageLabel: aggregates fixed and dice across multiple items, fixed first', () {
      final c = _char()
        ..equipment.addAll([
          EquipmentItem(name: 'A', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.spellDamage, value: 1, damageForm: EquipmentDamageForm.fixed),
            EquipmentBonus(type: EquipmentBonusType.spellDamage, value: 2, damageForm: EquipmentDamageForm.fixed),
          ]),
          EquipmentItem(name: 'B', bonuses: [
            EquipmentBonus(type: EquipmentBonusType.spellDamage, damageForm: EquipmentDamageForm.dice, diceCount: 3, die: 8),
          ]),
        ]);
      expect(c.spellDamageLabel(), '+3 +3d8');
    });

    test('round-trip: spellDamage bonus survives toMap/fromMap', () {
      final c = _char()
        ..equipment.add(EquipmentItem(name: 'Bacchetta', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.spellDamage, damageForm: EquipmentDamageForm.dice, diceCount: 2, die: 6),
        ]));
      final restored = Character.fromMap(c.toMap());
      expect(restored.spellDamageLabel(), c.spellDamageLabel());
      expect(restored.spellDamageLabel(), '+2d6');
      expect(restored.equipment.single.bonuses.single.type, EquipmentBonusType.spellDamage);
    });

    test('spellDamage is separate from the weapon damage aggregation', () {
      final c = _char()
        ..equipment.add(EquipmentItem(name: 'Mix', bonuses: [
          EquipmentBonus(type: EquipmentBonusType.damage, value: 5, damageForm: EquipmentDamageForm.fixed),
          EquipmentBonus(type: EquipmentBonusType.spellDamage, value: 1, damageForm: EquipmentDamageForm.fixed),
        ]));
      expect(c.equipmentDamageLabel(), '+5');
      expect(c.spellDamageLabel(), '+1');
    });
  });

  group('Bio languages + features as list entries', () {
    test('legacy plain-text profs_and_languages splits into one language per line', () {
      final map = _char().toMap()
        ..['profs_and_languages'] = 'Comune\nElfico\n\n  Nanico  ';

      final restored = Character.fromMap(map);

      // Blank lines dropped, each line trimmed.
      expect(restored.languages, ['Comune', 'Elfico', 'Nanico']);
    });

    test('legacy plain-text features_and_traits splits into entries with empty titles', () {
      final map = _char().toMap()
        ..['features_and_traits'] = 'Scurovisione\n\nFuria da Berserker';

      final restored = Character.fromMap(map);

      expect(restored.features, hasLength(2));
      expect(restored.features[0].title, '');
      expect(restored.features[0].description, 'Scurovisione');
      expect(restored.features[1].title, '');
      expect(restored.features[1].description, 'Furia da Berserker');
    });

    test('empty legacy blobs yield empty lists', () {
      final map = _char().toMap()
        ..['profs_and_languages'] = ''
        ..['features_and_traits'] = '';

      final restored = Character.fromMap(map);

      expect(restored.languages, isEmpty);
      expect(restored.features, isEmpty);
    });

    test('new JSON-list values round-trip via toMap/fromMap', () {
      final c = _char()
        ..languages.addAll(['Comune', 'Draconico'])
        ..features.addAll([
          CharacterFeature(title: 'Vista Nel Buio', description: '18 metri'),
          CharacterFeature(title: 'Fortunato', description: 'Ritira gli 1'),
        ]);

      final restored = Character.fromMap(c.toMap());

      expect(restored.languages, ['Comune', 'Draconico']);
      expect(restored.features, hasLength(2));
      expect(restored.features[0].title, 'Vista Nel Buio');
      expect(restored.features[0].description, '18 metri');
      expect(restored.features[1].title, 'Fortunato');
      expect(restored.features[1].description, 'Ritira gli 1');
    });

    test('toMap prunes fully-empty entries but keeps partially-filled ones', () {
      final c = _char()
        ..languages.addAll(['Comune', '', '   '])
        ..features.addAll([
          CharacterFeature(title: '', description: ''), // dropped
          CharacterFeature(title: '  ', description: ' '), // dropped
          CharacterFeature(title: 'Solo Titolo', description: ''), // kept
          CharacterFeature(title: '', description: 'Solo Descrizione'), // kept
        ]);

      final restored = Character.fromMap(c.toMap());

      expect(restored.languages, ['Comune']);
      expect(restored.features, hasLength(2));
      expect(restored.features[0].title, 'Solo Titolo');
      expect(restored.features[1].description, 'Solo Descrizione');
    });

    test('a fresh character has empty language and feature lists', () {
      final restored = Character.fromMap(_char().toMap());
      expect(restored.languages, isEmpty);
      expect(restored.features, isEmpty);
    });
  });

  group('Character prepared-spell limit', () {
    // A Character carrying `spells`, in list order, so tests can address a
    // spell by the index `togglePreparedSpell` takes.
    Character withSpells(List<Spell> spells, {int limit = 0}) =>
        Character(id: 'c1', preparedSpellsMax: limit, spells: spells);

    Spell spell(String name, int level, {bool prepared = false}) =>
        Spell(name: name, level: level, prepared: prepared);

    test('the prepared count excludes cantrips', () {
      final c = withSpells([
        spell('Prestidigitazione', 0, prepared: true),
        spell('Luce', 0, prepared: true),
        spell('Dardo Incantato', 1, prepared: true),
        spell('Scudo', 1),
      ]);

      expect(c.preparedSpellsCount, 1);
    });

    test('preparing is refused once the limit is reached', () {
      final c = withSpells([
        spell('Dardo Incantato', 1, prepared: true),
        spell('Scudo', 1),
      ], limit: 1);

      expect(c.canPrepareAnotherSpell, isFalse);
      expect(c.togglePreparedSpell(1), isFalse);
      expect(c.spells[1].prepared, isFalse);
      expect(c.preparedSpellsCount, 1);
    });

    test('preparing is allowed while below the limit', () {
      final c = withSpells([
        spell('Dardo Incantato', 1, prepared: true),
        spell('Scudo', 1),
      ], limit: 2);

      expect(c.canPrepareAnotherSpell, isTrue);
      expect(c.togglePreparedSpell(1), isTrue);
      expect(c.spells[1].prepared, isTrue);
      expect(c.preparedSpellsCount, 2);
    });

    test('a cantrip is refused whatever the limit', () {
      final c = withSpells([spell('Luce', 0)], limit: 9);

      expect(c.togglePreparedSpell(0), isFalse);
      expect(c.spells[0].prepared, isFalse);
    });

    test('a prepared cantrip is refused too — the flag is never flipped', () {
      final c = withSpells([spell('Luce', 0, prepared: true)], limit: 9);

      expect(c.togglePreparedSpell(0), isFalse);
      expect(c.spells[0].prepared, isTrue);
    });

    test('un-preparing always succeeds, even at the limit', () {
      final c = withSpells([
        spell('Dardo Incantato', 1, prepared: true),
        spell('Scudo', 1, prepared: true),
      ], limit: 2);

      expect(c.togglePreparedSpell(0), isTrue);
      expect(c.spells[0].prepared, isFalse);
      expect(c.preparedSpellsCount, 1);
    });

    test('un-preparing succeeds from an over-limit state', () {
      final c = withSpells([
        spell('Dardo Incantato', 1, prepared: true),
        spell('Scudo', 1, prepared: true),
        spell('Sonno', 1, prepared: true),
      ], limit: 1);

      expect(c.isOverPreparedLimit, isTrue);
      expect(c.togglePreparedSpell(2), isTrue);
      expect(c.preparedSpellsCount, 2);
      expect(c.isOverPreparedLimit, isTrue);
    });

    test('a limit of zero imposes no constraint', () {
      final c = withSpells([
        spell('Dardo Incantato', 1),
        spell('Scudo', 1),
        spell('Sonno', 1),
      ]);

      expect(c.canPrepareAnotherSpell, isTrue);
      expect(c.togglePreparedSpell(0), isTrue);
      expect(c.togglePreparedSpell(1), isTrue);
      expect(c.togglePreparedSpell(2), isTrue);
      expect(c.preparedSpellsCount, 3);
      expect(c.isOverPreparedLimit, isFalse);
    });

    test('lowering the limit below the prepared count keeps every flag', () {
      final c = withSpells([
        spell('Dardo Incantato', 1, prepared: true),
        spell('Scudo', 1, prepared: true),
        spell('Sonno', 1, prepared: true),
      ], limit: 3);

      c.preparedSpellsMax = 1;

      expect(c.spells.every((s) => s.prepared), isTrue);
      expect(c.preparedSpellsCount, 3);
      expect(c.isOverPreparedLimit, isTrue);
      expect(c.canPrepareAnotherSpell, isFalse);
    });

    test('preparing stays refused while over the limit', () {
      final c = withSpells([
        spell('Dardo Incantato', 1, prepared: true),
        spell('Scudo', 1, prepared: true),
        spell('Sonno', 1),
      ], limit: 1);

      expect(c.togglePreparedSpell(2), isFalse);
      expect(c.spells[2].prepared, isFalse);
    });

    test('an out-of-range index is refused and changes nothing', () {
      final c = withSpells([spell('Scudo', 1)], limit: 3);

      expect(c.togglePreparedSpell(5), isFalse);
      expect(c.togglePreparedSpell(-1), isFalse);
      expect(c.spells.single.prepared, isFalse);
    });

    test('the limit survives toMap -> fromMap', () {
      final c = withSpells([spell('Scudo', 1)], limit: 5);

      final restored = Character.fromMap(c.toMap());

      expect(restored.preparedSpellsMax, 5);
    });

    test('a map with no value for the limit yields zero', () {
      final legacyMap = withSpells([spell('Scudo', 1)], limit: 5).toMap()
        ..remove('prepared_spells_max');

      expect(() => Character.fromMap(legacyMap), returnsNormally);
      expect(Character.fromMap(legacyMap).preparedSpellsMax, 0);
    });
  });

  group('Character updateSpell (spell detail edit)', () {
    // Same convention as the prepared-spell limit group above: a Character
    // carrying `spells` in list order, addressed by the index `updateSpell`
    // takes.
    Character withSpells(List<Spell> spells, {int limit = 0}) =>
        Character(id: 'c1', preparedSpellsMax: limit, spells: spells);

    // A spell with all ten descriptive fields set to distinct, recognisable
    // values, for the "all fields overwritten" and "round trip" tests.
    Spell fullSpell({
      String name = 'Palla di Fuoco',
      int level = 3,
      bool prepared = false,
      String school = 'Invocazione',
      String castingTime = '1 azione',
      String range = '45 metri',
      String components = 'V, S, M',
      String duration = 'Istantanea',
      String description = 'Una palla di fuoco esplode in un\'area.',
      String damage = '8d6 fuoco',
    }) =>
        Spell(
          name: name,
          level: level,
          prepared: prepared,
          school: school,
          castingTime: castingTime,
          range: range,
          components: components,
          duration: duration,
          description: description,
          damage: damage,
        );

    test('an edit preserves the prepared flag of a prepared spell', () {
      final c = withSpells([Spell(name: 'Scudo', level: 1, prepared: true)]);

      c.updateSpell(0, Spell(name: 'Scudo', level: 1));

      expect(c.spells[0].prepared, isTrue);
    });

    test('an edit preserves the unprepared state of an unprepared spell', () {
      final c = withSpells([Spell(name: 'Scudo', level: 1, prepared: false)]);

      c.updateSpell(0, Spell(name: 'Scudo', level: 1));

      expect(c.spells[0].prepared, isFalse);
    });

    test('the caller-supplied prepared value is ignored in both directions', () {
      final preparedCase = withSpells([Spell(name: 'Scudo', level: 1, prepared: true)]);
      // Caller passes prepared: false on a spell that is actually prepared —
      // the flag must not follow the caller.
      preparedCase.updateSpell(0, Spell(name: 'Scudo', level: 1, prepared: false));
      expect(preparedCase.spells[0].prepared, isTrue);

      final unpreparedCase = withSpells([Spell(name: 'Scudo', level: 1, prepared: false)]);
      // Caller passes prepared: true on a spell that is actually unprepared —
      // editing must not be a back door into preparing it.
      unpreparedCase.updateSpell(0, Spell(name: 'Scudo', level: 1, prepared: true));
      expect(unpreparedCase.spells[0].prepared, isFalse);
    });

    test('an edit whose level is zero clears the prepared flag', () {
      final c = withSpells([Spell(name: 'Dardo Incantato', level: 1, prepared: true)]);

      c.updateSpell(0, Spell(name: 'Dardo Incantato', level: 0));

      expect(c.spells[0].prepared, isFalse);
    });

    test('an edit from level zero to a non-zero level leaves the spell unprepared', () {
      // A cantrip can never legitimately be prepared through
      // togglePreparedSpell, but updateSpell must not rely on that
      // invariant holding upstream — so the stored flag is forced to true
      // here directly, bypassing the toggle, to prove the model itself
      // guards this case.
      final c = withSpells([Spell(name: 'Luce', level: 0, prepared: true)]);

      c.updateSpell(0, Spell(name: 'Luce', level: 1));

      expect(c.spells[0].prepared, isFalse);
    });

    test('all ten descriptive fields are overwritten by the incoming spell', () {
      final c = withSpells([
        Spell(
          name: 'Vecchio Nome',
          level: 1,
          school: 'Vecchia Scuola',
          castingTime: 'Vecchio Tempo',
          range: 'Vecchia Gittata',
          components: 'Vecchi Componenti',
          duration: 'Vecchia Durata',
          description: 'Vecchia Descrizione',
          damage: 'Vecchio Danno',
        ),
      ]);
      final edited = fullSpell();

      c.updateSpell(0, edited);

      final s = c.spells[0];
      expect(s.name, edited.name);
      expect(s.level, edited.level);
      expect(s.school, edited.school);
      expect(s.castingTime, edited.castingTime);
      expect(s.range, edited.range);
      expect(s.components, edited.components);
      expect(s.duration, edited.duration);
      expect(s.description, edited.description);
      expect(s.damage, edited.damage);
    });

    test('an out-of-range index changes nothing', () {
      final c = withSpells([Spell(name: 'Scudo', level: 1, prepared: true)]);

      c.updateSpell(5, Spell(name: 'Non dovrebbe applicarsi', level: 2));
      c.updateSpell(-1, Spell(name: 'Non dovrebbe applicarsi', level: 2));

      expect(c.spells.single.name, 'Scudo');
      expect(c.spells.single.level, 1);
      expect(c.spells.single.prepared, isTrue);
    });

    test('the prepared count and over-limit flag read correctly after an edit', () {
      final c = withSpells([
        Spell(name: 'Dardo Incantato', level: 1, prepared: true),
        Spell(name: 'Scudo', level: 1, prepared: true),
      ], limit: 1);
      expect(c.isOverPreparedLimit, isTrue);

      // Editing the first spell down to a cantrip drops it out of the
      // prepared count entirely, which can only bring the character closer
      // to (or under) the limit, never push it further over.
      c.updateSpell(0, Spell(name: 'Dardo Incantato', level: 0));

      expect(c.preparedSpellsCount, 1);
      expect(c.isOverPreparedLimit, isFalse);
    });

    test('an edit round-trips through the Character map serialisation', () {
      final c = withSpells([Spell(name: 'Scudo', level: 1, prepared: true)]);

      c.updateSpell(0, fullSpell(name: 'Scudo Maggiore', level: 2, prepared: false));
      final restored = Character.fromMap(c.toMap());

      final s = restored.spells.single;
      expect(s.name, 'Scudo Maggiore');
      expect(s.level, 2);
      // Carried forward from the spell that was there before the edit,
      // not from the `prepared: false` the caller passed to fullSpell().
      expect(s.prepared, isTrue);
      expect(s.school, 'Invocazione');
      expect(s.castingTime, '1 azione');
      expect(s.range, '45 metri');
      expect(s.components, 'V, S, M');
      expect(s.duration, 'Istantanea');
      expect(s.description, 'Una palla di fuoco esplode in un\'area.');
      expect(s.damage, '8d6 fuoco');
    });
  });
}
