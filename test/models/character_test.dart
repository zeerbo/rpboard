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
}
