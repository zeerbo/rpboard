import 'dart:convert';

class Attack {
  String name;
  String attackBonus;
  String damage;
  String type;

  Attack({
    this.name = '',
    this.attackBonus = '',
    this.damage = '',
    this.type = '',
  });

  factory Attack.fromJson(Map<String, dynamic> j) => Attack(
        name: j['name'] ?? '',
        attackBonus: j['attackBonus'] ?? '',
        damage: j['damage'] ?? '',
        type: j['type'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'attackBonus': attackBonus,
        'damage': damage,
        'type': type,
      };
}

class SpellSlot {
  int level;
  int total;
  int used;

  SpellSlot({required this.level, required this.total, this.used = 0});

  factory SpellSlot.fromJson(Map<String, dynamic> j) => SpellSlot(
        level: j['level'] ?? 1,
        total: j['total'] ?? 0,
        used: j['used'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        'total': total,
        'used': used,
      };
}

class Spell {
  String name;
  int level;
  String school;
  bool prepared;
  String castingTime;
  String range;
  String components;
  String duration;
  String description;

  Spell({
    this.name = '',
    this.level = 0,
    this.school = '',
    this.prepared = false,
    this.castingTime = '',
    this.range = '',
    this.components = '',
    this.duration = '',
    this.description = '',
  });

  factory Spell.fromJson(Map<String, dynamic> j) => Spell(
        name: j['name'] ?? '',
        level: j['level'] ?? 0,
        school: j['school'] ?? '',
        prepared: j['prepared'] ?? false,
        castingTime: j['castingTime'] ?? '',
        range: j['range'] ?? '',
        components: j['components'] ?? '',
        duration: j['duration'] ?? '',
        description: j['description'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'school': school,
        'prepared': prepared,
        'castingTime': castingTime,
        'range': range,
        'components': components,
        'duration': duration,
        'description': description,
      };
}

class Armor {
  String name;
  int baseAc;
  bool addsDex;

  Armor({this.name = '', this.baseAc = 10, this.addsDex = false});

  factory Armor.fromJson(Map<String, dynamic> j) => Armor(
        name: j['name'] ?? '',
        baseAc: j['baseAc'] ?? 10,
        addsDex: j['addsDex'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseAc': baseAc,
        'addsDex': addsDex,
      };
}

enum EquipmentBonusType { ac, attack, damage, initiative, speed, savingThrow, ability }

enum EquipmentDamageForm { fixed, dice }

/// A single configurable bonus on an EquipmentItem. One [type] plus the
/// fields that type needs; unused fields keep harmless defaults. Global:
/// bonuses apply across the whole sheet, never per-attack.
class EquipmentBonus {
  EquipmentBonusType type;
  /// Integer magnitude for ac/attack/initiative/speed, and for damage when
  /// [damageForm] is fixed.
  int value;
  /// For savingThrow/ability: one of 'str','dex','con','int','wis','cha' or
  /// 'all'. Empty for other types.
  String target;
  /// For damage bonuses only: fixed magnitude vs a dice term.
  EquipmentDamageForm damageForm;
  /// For damage dice: number of dice and die faces (e.g. 3 and 8 => 3d8).
  int diceCount;
  int die;

  EquipmentBonus({
    this.type = EquipmentBonusType.ac,
    this.value = 0,
    this.target = '',
    this.damageForm = EquipmentDamageForm.fixed,
    this.diceCount = 0,
    this.die = 0,
  });

  factory EquipmentBonus.fromJson(Map<String, dynamic> j) => EquipmentBonus(
        type: _bonusTypeFromName(j['type']),
        value: j['value'] ?? 0,
        target: j['target'] ?? '',
        damageForm: (j['damageForm'] == 'dice')
            ? EquipmentDamageForm.dice
            : EquipmentDamageForm.fixed,
        diceCount: j['diceCount'] ?? 0,
        die: j['die'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'value': value,
        'target': target,
        'damageForm': damageForm.name,
        'diceCount': diceCount,
        'die': die,
      };
}

/// Tolerant enum parse: unknown/missing names fall back to `ac`, never throw.
EquipmentBonusType _bonusTypeFromName(Object? name) {
  for (final t in EquipmentBonusType.values) {
    if (t.name == name) return t;
  }
  return EquipmentBonusType.ac;
}

class EquipmentItem {
  String name;
  List<EquipmentBonus> bonuses;
  EquipmentItem({this.name = '', List<EquipmentBonus>? bonuses})
      : bonuses = bonuses ?? [];

  factory EquipmentItem.fromJson(Map<String, dynamic> j) => EquipmentItem(
        name: j['name'] ?? '',
        bonuses: ((j['bonuses'] as List?) ?? [])
            .map((b) => EquipmentBonus.fromJson(b as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'bonuses': bonuses.map((b) => b.toJson()).toList(),
      };
}

class InventoryItem {
  String name;
  int quantity;
  double weight;
  String notes;

  InventoryItem({
    this.name = '',
    this.quantity = 1,
    this.weight = 0,
    this.notes = '',
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        name: j['name'] ?? '',
        quantity: j['quantity'] ?? 1,
        weight: (j['weight'] ?? 0).toDouble(),
        notes: j['notes'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'weight': weight,
        'notes': notes,
      };
}

const List<String> kSkills = [
  'Acrobatica',
  'Addestrare Animali',
  'Arcano',
  'Atletica',
  'Furtività',
  'Inganno',
  'Intrattenere',
  'Intuizione',
  'Intimidire',
  'Investigare',
  'Medicina',
  'Natura',
  'Percezione',
  'Persuasione',
  'Rapidità di Mano',
  'Religione',
  'Storia',
  'Sopravvivenza',
];

/// Explicit, case-insensitive, whitespace-tolerant mapping from the six
/// Italian ability names to their short keys. Keys here are already
/// lower-cased; callers normalize the candidate string (trim + lowercase)
/// before looking it up. No substring slicing — unrecognized text (including
/// an empty string) simply misses this map and falls back to a zero
/// modifier, it never throws or coincidentally matches the wrong ability.
const Map<String, String> kAbilityNameToKey = {
  'forza': 'str',
  'destrezza': 'dex',
  'costituzione': 'con',
  'intelligenza': 'int',
  'saggezza': 'wis',
  'carisma': 'cha',
};

const Map<String, String> kSkillAbility = {
  'Acrobatica': 'dex',
  'Addestrare Animali': 'wis',
  'Arcano': 'int',
  'Atletica': 'str',
  'Furtività': 'dex',
  'Inganno': 'cha',
  'Intrattenere': 'cha',
  'Intuizione': 'wis',
  'Intimidire': 'cha',
  'Investigare': 'int',
  'Medicina': 'wis',
  'Natura': 'int',
  'Percezione': 'wis',
  'Persuasione': 'cha',
  'Rapidità di Mano': 'dex',
  'Religione': 'int',
  'Storia': 'int',
  'Sopravvivenza': 'wis',
};

class Character {
  final String id;
  String name;
  String playerName;
  String race;
  String characterClass;
  String subclass;
  int level;
  String background;
  String alignment;
  int experiencePoints;

  // Ability scores
  int strength;
  int dexterity;
  int constitution;
  int intelligence;
  int wisdom;
  int charisma;

  // Combat
  int hpMax;
  int hpCurrent;
  int hpTemp;
  int armorClass;
  int initiativeBonus;
  int speed;
  String hitDice;
  int hitDiceUsed;
  bool hasInspiration;

  // Proficiencies
  List<String> savingThrowProfs;
  List<String> skillProfs;
  List<String> skillExpertise;

  // Death saves
  int deathSaveSuccesses;
  int deathSaveFailures;
  bool isDead;
  bool isStable;

  // Inventory
  List<InventoryItem> inventory;
  int cp;
  int sp;
  int ep;
  int gp;
  int pp;

  // Traits
  String personalityTraits;
  String ideals;
  String bonds;
  String flaws;
  String featuresAndTraits;
  String profsAndLanguages;

  // Backstory
  String backstory;
  String appearance;
  int age;
  String height;
  String weight;
  String eyes;
  String skin;
  String hair;

  // Attacks
  List<Attack> attacks;

  // Equipment
  Armor? armor;
  List<EquipmentItem> equipment;

  // Spellcasting
  String spellcastingAbility;
  List<SpellSlot> spellSlots;
  List<Spell> spells;

  // Notes
  String notes;

  Character({
    required this.id,
    this.name = '',
    this.playerName = '',
    this.race = '',
    this.characterClass = '',
    this.subclass = '',
    this.level = 1,
    this.background = '',
    this.alignment = '',
    this.experiencePoints = 0,
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
    this.hpMax = 0,
    this.hpCurrent = 0,
    this.hpTemp = 0,
    this.armorClass = 10,
    this.initiativeBonus = 0,
    this.speed = 30,
    this.hitDice = '1d8',
    this.hitDiceUsed = 0,
    this.hasInspiration = false,
    List<String>? savingThrowProfs,
    List<String>? skillProfs,
    List<String>? skillExpertise,
    this.deathSaveSuccesses = 0,
    this.deathSaveFailures = 0,
    this.isDead = false,
    this.isStable = false,
    List<InventoryItem>? inventory,
    this.cp = 0,
    this.sp = 0,
    this.ep = 0,
    this.gp = 0,
    this.pp = 0,
    this.personalityTraits = '',
    this.ideals = '',
    this.bonds = '',
    this.flaws = '',
    this.featuresAndTraits = '',
    this.profsAndLanguages = '',
    this.backstory = '',
    this.appearance = '',
    this.age = 0,
    this.height = '',
    this.weight = '',
    this.eyes = '',
    this.skin = '',
    this.hair = '',
    List<Attack>? attacks,
    this.armor,
    List<EquipmentItem>? equipment,
    this.spellcastingAbility = '',
    List<SpellSlot>? spellSlots,
    List<Spell>? spells,
    this.notes = '',
  })  : savingThrowProfs = savingThrowProfs ?? [],
        skillProfs = skillProfs ?? [],
        skillExpertise = skillExpertise ?? [],
        inventory = inventory ?? [],
        attacks = attacks ?? [],
        equipment = equipment ?? [],
        spellSlots = spellSlots ?? [],
        spells = spells ?? [];

  int get proficiencyBonus {
    if (level < 5) return 2;
    if (level < 9) return 3;
    if (level < 13) return 4;
    if (level < 17) return 5;
    return 6;
  }

  int mod(int score) => ((score - 10) / 2).floor();

  /// Sums the `.value` of all bonuses of [type] whose target matches
  /// [ability] exactly or is the 'all' sentinel — for `ability` and
  /// `savingThrow` bonuses, which carry a target.
  int sumTargetedBonus(EquipmentBonusType type, String ability) {
    var total = 0;
    for (final item in equipment) {
      for (final b in item.bonuses) {
        if (b.type == type && (b.target == ability || b.target == 'all')) {
          total += b.value;
        }
      }
    }
    return total;
  }

  // ── Effective ability scores ─────────────────────────────────────────────
  //
  // Nude score plus any equipment `ability` bonuses targeting that ability
  // (or 'all'). The six *Mod getters below read these instead of the nude
  // fields, so every derivation built on them (abilityMod, skillBonus,
  // savingThrowBonus, spellcasting) propagates automatically.

  int get effectiveStrength => strength + sumTargetedBonus(EquipmentBonusType.ability, 'str');
  int get effectiveDexterity => dexterity + sumTargetedBonus(EquipmentBonusType.ability, 'dex');
  int get effectiveConstitution => constitution + sumTargetedBonus(EquipmentBonusType.ability, 'con');
  int get effectiveIntelligence => intelligence + sumTargetedBonus(EquipmentBonusType.ability, 'int');
  int get effectiveWisdom => wisdom + sumTargetedBonus(EquipmentBonusType.ability, 'wis');
  int get effectiveCharisma => charisma + sumTargetedBonus(EquipmentBonusType.ability, 'cha');

  /// Effective (post-equipment) score for an ability key ('str'…'cha'), for
  /// the UI badge. Defaults to 10 for an unrecognized key.
  int effectiveAbilityScore(String ability) {
    switch (ability) {
      case 'str': return effectiveStrength;
      case 'dex': return effectiveDexterity;
      case 'con': return effectiveConstitution;
      case 'int': return effectiveIntelligence;
      case 'wis': return effectiveWisdom;
      case 'cha': return effectiveCharisma;
      default: return 10;
    }
  }

  /// Nude (pre-equipment) score for an ability key ('str'…'cha'), for the UI
  /// badge. Defaults to 10 for an unrecognized key.
  int nudeAbilityScore(String ability) {
    switch (ability) {
      case 'str': return strength;
      case 'dex': return dexterity;
      case 'con': return constitution;
      case 'int': return intelligence;
      case 'wis': return wisdom;
      case 'cha': return charisma;
      default: return 10;
    }
  }

  int get strMod => mod(effectiveStrength);
  int get dexMod => mod(effectiveDexterity);
  int get conMod => mod(effectiveConstitution);
  int get intMod => mod(effectiveIntelligence);
  int get wisMod => mod(effectiveWisdom);
  int get chaMod => mod(effectiveCharisma);

  int abilityMod(String ability) {
    switch (ability) {
      case 'str': return strMod;
      case 'dex': return dexMod;
      case 'con': return conMod;
      case 'int': return intMod;
      case 'wis': return wisMod;
      case 'cha': return chaMod;
      default: return 0;
    }
  }

  /// Sums the `value` of every equipment bonus of [type] across all
  /// [equipment] items. Public: later tickets (and tests) reuse this for
  /// their own bonus types.
  int sumEquipmentBonus(EquipmentBonusType type) {
    var total = 0;
    for (final item in equipment) {
      for (final b in item.bonuses) {
        if (b.type == type) total += b.value;
      }
    }
    return total;
  }

  /// The character's final AC. With [armor] set, the base is the armor's
  /// `baseAc` plus [dexMod] when `addsDex` is true, or `baseAc` exactly when
  /// it's false (a fixed CA). Without armor, the base is the manual
  /// [armorClass] field the player typed in directly. On top of that base,
  /// every equipped item's additive `ac` bonus is summed in.
  int get armorClassEffective {
    final base = armor != null
        ? (armor!.addsDex ? armor!.baseAc + dexMod : armor!.baseAc)
        : armorClass;
    return base + sumEquipmentBonus(EquipmentBonusType.ac);
  }

  /// Initiative including equipment `initiative` bonuses, over the nude
  /// [initiativeBonus] the player typed.
  int get initiativeEffective =>
      initiativeBonus + sumEquipmentBonus(EquipmentBonusType.initiative);

  /// Speed including equipment `speed` bonuses, over the nude [speed].
  int get speedEffective => speed + sumEquipmentBonus(EquipmentBonusType.speed);

  /// Aggregation for a badge next to any equipment-affected field: the nude
  /// [base] the player typed, the [effective] total, and the [equip] share
  /// (effective - base). When [equip] == 0 the UI shows no badge.
  ({int base, int effective, int equip}) equipmentBadge(int base, int effective) =>
      (base: base, effective: effective, equip: effective - base);

  /// The equipment `attack` bonus applied globally to every attack.
  int get attackEquipmentBonus => sumEquipmentBonus(EquipmentBonusType.attack);

  /// For a given attack: the equipment share, and the computed total when
  /// [Attack.attackBonus] is a pure integer (e.g. "+5" -> 5). When it isn't a
  /// pure integer, [total] is null so the displayed total is never falsified,
  /// while [equip] stays available to show alongside.
  ({int? total, int equip}) attackWithEquipment(Attack a) {
    final equip = attackEquipmentBonus;
    final base = int.tryParse(a.attackBonus.trim()); // Dart parses a leading '+'
    return (total: base == null ? null : base + equip, equip: equip);
  }

  /// Aggregates all equipment `damage` bonuses into a fixed part (summed) plus
  /// the list of dice terms (e.g. 3d8). Empty/zero when there are none.
  ({int fixed, List<({int count, int die})> dice}) equipmentDamageBonus() {
    var fixed = 0;
    final dice = <({int count, int die})>[];
    for (final item in equipment) {
      for (final b in item.bonuses) {
        if (b.type != EquipmentBonusType.damage) continue;
        if (b.damageForm == EquipmentDamageForm.fixed) {
          fixed += b.value;
        } else if (b.diceCount > 0 && b.die > 0) {
          dice.add((count: b.diceCount, die: b.die));
        }
      }
    }
    return (fixed: fixed, dice: dice);
  }

  /// Display string for [equipmentDamageBonus], e.g. "+1", "+3d8", or
  /// "+1 +3d8" (fixed first when nonzero, then each dice term). Null when
  /// there's nothing to show, so the UI can conditionally render.
  String? equipmentDamageLabel() {
    final agg = equipmentDamageBonus();
    if (agg.fixed == 0 && agg.dice.isEmpty) return null;
    final parts = <String>[];
    if (agg.fixed != 0) parts.add('${agg.fixed >= 0 ? "+" : ""}${agg.fixed}');
    for (final d in agg.dice) {
      parts.add('+${d.count}d${d.die}');
    }
    return parts.join(' ');
  }

  int skillBonus(String skill) {
    final ability = kSkillAbility[skill] ?? 'dex';
    final base = abilityMod(ability);
    if (skillExpertise.contains(skill)) return base + proficiencyBonus * 2;
    if (skillProfs.contains(skill)) return base + proficiencyBonus;
    return base;
  }

  /// The skill bonus computed from NUDE ability scores, ignoring equipment
  /// `ability` score bonuses — the value before equipment. A skill has no
  /// direct equipment bonus type, so its equip share comes entirely through
  /// the ability score; the UI shows `skillBonus(s) - skillBonusBase(s)`.
  int skillBonusBase(String skill) {
    final ability = kSkillAbility[skill] ?? 'dex';
    final base = mod(nudeAbilityScore(ability));
    if (skillExpertise.contains(skill)) return base + proficiencyBonus * 2;
    if (skillProfs.contains(skill)) return base + proficiencyBonus;
    return base;
  }

  int savingThrowBonus(String ability) {
    final base = abilityMod(ability); // already effective
    final withProf = savingThrowProfs.contains(ability) ? base + proficiencyBonus : base;
    return withProf + sumTargetedBonus(EquipmentBonusType.savingThrow, ability);
  }

  /// The saving-throw bonus computed from NUDE ability scores, ignoring all
  /// equipment (both `ability` score bonuses and targeted `savingThrow`
  /// bonuses) — i.e. the value before equipment. The equip share shown in
  /// the UI is `savingThrowBonus(a) - savingThrowBonusBase(a)`.
  int savingThrowBonusBase(String ability) {
    final base = mod(nudeAbilityScore(ability));
    return savingThrowProfs.contains(ability) ? base + proficiencyBonus : base;
  }

  String get passivePerception => '${10 + skillBonus('Percezione')}';

  // ── Spellcasting ──────────────────────────────────────────────────────────
  //
  // Replaces the screen's old `spellcastingAbility.toLowerCase().substring(0,3)`
  // shortcut, which only coincidentally equalled 'int' for 'Intelligenza' and
  // silently produced a zero modifier for every other ability. Normalization
  // here goes through the explicit `kAbilityNameToKey` table instead, so any
  // of the six Italian names — in any case, with any surrounding whitespace —
  // resolves correctly, and anything unrecognized (including an empty
  // string) falls back to a zero modifier rather than throwing or matching
  // the wrong ability. `spellcastingAbility` itself stays free text.

  /// The ability modifier driving spellcasting, resolved from the free-text
  /// [spellcastingAbility] via [kAbilityNameToKey]. Zero for unrecognized or
  /// empty text.
  int get spellcastingAbilityMod {
    final key = kAbilityNameToKey[spellcastingAbility.trim().toLowerCase()];
    return key == null ? 0 : abilityMod(key);
  }

  int get spellSaveDC => 8 + proficiencyBonus + spellcastingAbilityMod;

  int get spellAttackBonus => proficiencyBonus + spellcastingAbilityMod;

  // ── Spell slots ───────────────────────────────────────────────────────────
  //
  // Preserves the screen's exact clamps: setting a level's total to 0 (or
  // below) removes that level's row entirely; a slot can only be used while
  // `used < total`, and only restored while `used > 0`.

  /// Sets the total slots for [level]. A total of 0 or less removes that
  /// level's row instead of leaving an empty one.
  void setSpellSlotTotal(int level, int total) {
    final idx = spellSlots.indexWhere((s) => s.level == level);
    if (total <= 0) {
      if (idx >= 0) spellSlots.removeAt(idx);
      return;
    }
    if (idx >= 0) {
      spellSlots[idx].total = total;
    } else {
      spellSlots.add(SpellSlot(level: level, total: total));
    }
  }

  /// Spends one slot at [level]. No-op once `used == total` (or if the level
  /// has no row at all).
  void useSpellSlot(int level) {
    final idx = spellSlots.indexWhere((s) => s.level == level);
    if (idx < 0) return;
    final slot = spellSlots[idx];
    if (slot.used < slot.total) slot.used++;
  }

  /// Restores one spent slot at [level]. No-op once `used == 0` (or if the
  /// level has no row at all).
  void restoreSpellSlot(int level) {
    final idx = spellSlots.indexWhere((s) => s.level == level);
    if (idx < 0) return;
    final slot = spellSlots[idx];
    if (slot.used > 0) slot.used--;
  }

  // ── Death saves ───────────────────────────────────────────────────────────
  //
  // Toggle-down semantics: clicking box `i` sets the count to `i` if it was
  // already above `i` (undo back down to that box), otherwise `i + 1`.
  //
  // isDead/isStable decision: these two persisted-but-previously-inert
  // columns are now maintained as a side effect of ticking. Reaching 3
  // failures sets `isDead = true` and resets both counters to 0; reaching 3
  // successes sets `isStable = true` and resets both counters to 0. Once set,
  // `isDead`/`isStable` are sticky — resetDeathSaves() (the player-facing
  // "Reset" button) only zeroes the two counters, it does not clear a
  // previously-reached isDead/isStable, since un-deciding a death outcome is
  // not something the counters alone should silently do.

  /// Ticks the success box at index [i] (0, 1, or 2). Reaching the third
  /// success sets [isStable] and resets both counters.
  void tickDeathSaveSuccess(int i) {
    deathSaveSuccesses = deathSaveSuccesses > i ? i : i + 1;
    if (deathSaveSuccesses >= 3) {
      isStable = true;
      deathSaveSuccesses = 0;
      deathSaveFailures = 0;
    }
  }

  /// Ticks the failure box at index [i] (0, 1, or 2). Reaching the third
  /// failure sets [isDead] and resets both counters.
  void tickDeathSaveFailure(int i) {
    deathSaveFailures = deathSaveFailures > i ? i : i + 1;
    if (deathSaveFailures >= 3) {
      isDead = true;
      deathSaveSuccesses = 0;
      deathSaveFailures = 0;
    }
  }

  /// Zeroes both death-save counters. Does not clear [isDead]/[isStable].
  void resetDeathSaves() {
    deathSaveSuccesses = 0;
    deathSaveFailures = 0;
  }

  /// Clears a previously-reached death outcome and zeroes the counters — the
  /// explicit "back to normal" action (e.g. after a heal or a revive). This is
  /// the only path that un-sets the sticky [isDead]/[isStable] flags, kept
  /// separate from [resetDeathSaves] so a counter reset never silently undoes
  /// a death.
  void clearDeathOutcome() {
    isDead = false;
    isStable = false;
    deathSaveSuccesses = 0;
    deathSaveFailures = 0;
  }

  factory Character.fromMap(Map<String, dynamic> m) {
    List<Attack> parseAttacks() {
      try {
        return (jsonDecode(m['attacks'] ?? '[]') as List)
            .map((a) => Attack.fromJson(a as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    List<SpellSlot> parseSpellSlots() {
      try {
        return (jsonDecode(m['spell_slots'] ?? '[]') as List)
            .map((s) => SpellSlot.fromJson(s as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    List<Spell> parseSpells() {
      try {
        return (jsonDecode(m['spells'] ?? '[]') as List)
            .map((s) => Spell.fromJson(s as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    List<InventoryItem> parseInventory() {
      try {
        return (jsonDecode(m['inventory'] ?? '[]') as List)
            .map((i) => InventoryItem.fromJson(i as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    List<String> parseStringList(String key) {
      try {
        return List<String>.from(jsonDecode(m[key] ?? '[]') as List);
      } catch (_) {
        return [];
      }
    }

    Armor? parseArmor() {
      final raw = m['armor'];
      if (raw == null || (raw is String && raw.isEmpty)) return null;
      try {
        return Armor.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }

    List<EquipmentItem> parseEquipment() {
      try {
        return (jsonDecode(m['equipment'] ?? '[]') as List)
            .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }

    return Character(
      id: m['id'] as String,
      name: m['name'] ?? '',
      playerName: m['player_name'] ?? '',
      race: m['race'] ?? '',
      characterClass: m['character_class'] ?? '',
      subclass: m['subclass'] ?? '',
      level: m['level'] ?? 1,
      background: m['background'] ?? '',
      alignment: m['alignment'] ?? '',
      experiencePoints: m['experience_points'] ?? 0,
      strength: m['strength'] ?? 10,
      dexterity: m['dexterity'] ?? 10,
      constitution: m['constitution'] ?? 10,
      intelligence: m['intelligence'] ?? 10,
      wisdom: m['wisdom'] ?? 10,
      charisma: m['charisma'] ?? 10,
      hpMax: m['hp_max'] ?? 0,
      hpCurrent: m['hp_current'] ?? 0,
      hpTemp: m['hp_temp'] ?? 0,
      armorClass: m['armor_class'] ?? 10,
      initiativeBonus: m['initiative_bonus'] ?? 0,
      speed: m['speed'] ?? 30,
      hitDice: m['hit_dice'] ?? '1d8',
      hitDiceUsed: m['hit_dice_used'] ?? 0,
      hasInspiration: (m['has_inspiration'] ?? 0) == 1,
      savingThrowProfs: parseStringList('saving_throw_profs'),
      skillProfs: parseStringList('skill_profs'),
      skillExpertise: parseStringList('skill_expertise'),
      deathSaveSuccesses: m['death_save_successes'] ?? 0,
      deathSaveFailures: m['death_save_failures'] ?? 0,
      isDead: (m['is_dead'] ?? 0) == 1,
      isStable: (m['is_stable'] ?? 0) == 1,
      inventory: parseInventory(),
      cp: m['cp'] ?? 0,
      sp: m['sp'] ?? 0,
      ep: m['ep'] ?? 0,
      gp: m['gp'] ?? 0,
      pp: m['pp'] ?? 0,
      personalityTraits: m['personality_traits'] ?? '',
      ideals: m['ideals'] ?? '',
      bonds: m['bonds'] ?? '',
      flaws: m['flaws'] ?? '',
      featuresAndTraits: m['features_and_traits'] ?? '',
      profsAndLanguages: m['profs_and_languages'] ?? '',
      backstory: m['backstory'] ?? '',
      appearance: m['appearance'] ?? '',
      age: m['age'] ?? 0,
      height: m['height'] ?? '',
      weight: m['weight'] ?? '',
      eyes: m['eyes'] ?? '',
      skin: m['skin'] ?? '',
      hair: m['hair'] ?? '',
      attacks: parseAttacks(),
      armor: parseArmor(),
      equipment: parseEquipment(),
      spellcastingAbility: m['spellcasting_ability'] ?? '',
      spellSlots: parseSpellSlots(),
      spells: parseSpells(),
      notes: m['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'player_name': playerName,
        'race': race,
        'character_class': characterClass,
        'subclass': subclass,
        'level': level,
        'background': background,
        'alignment': alignment,
        'experience_points': experiencePoints,
        'strength': strength,
        'dexterity': dexterity,
        'constitution': constitution,
        'intelligence': intelligence,
        'wisdom': wisdom,
        'charisma': charisma,
        'hp_max': hpMax,
        'hp_current': hpCurrent,
        'hp_temp': hpTemp,
        'armor_class': armorClass,
        'initiative_bonus': initiativeBonus,
        'speed': speed,
        'hit_dice': hitDice,
        'hit_dice_used': hitDiceUsed,
        'has_inspiration': hasInspiration ? 1 : 0,
        'saving_throw_profs': jsonEncode(savingThrowProfs),
        'skill_profs': jsonEncode(skillProfs),
        'skill_expertise': jsonEncode(skillExpertise),
        'death_save_successes': deathSaveSuccesses,
        'death_save_failures': deathSaveFailures,
        'is_dead': isDead ? 1 : 0,
        'is_stable': isStable ? 1 : 0,
        'inventory': jsonEncode(inventory.map((i) => i.toJson()).toList()),
        'cp': cp,
        'sp': sp,
        'ep': ep,
        'gp': gp,
        'pp': pp,
        'personality_traits': personalityTraits,
        'ideals': ideals,
        'bonds': bonds,
        'flaws': flaws,
        'features_and_traits': featuresAndTraits,
        'profs_and_languages': profsAndLanguages,
        'backstory': backstory,
        'appearance': appearance,
        'age': age,
        'height': height,
        'weight': weight,
        'eyes': eyes,
        'skin': skin,
        'hair': hair,
        'attacks': jsonEncode(attacks.map((a) => a.toJson()).toList()),
        'armor': armor == null ? null : jsonEncode(armor!.toJson()),
        'equipment': jsonEncode(equipment.map((e) => e.toJson()).toList()),
        'spellcasting_ability': spellcastingAbility,
        'spell_slots': jsonEncode(spellSlots.map((s) => s.toJson()).toList()),
        'spells': jsonEncode(spells.map((s) => s.toJson()).toList()),
        'notes': notes,
      };
}
