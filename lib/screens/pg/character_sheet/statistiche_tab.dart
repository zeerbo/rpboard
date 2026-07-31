import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/character.dart';
import 'shared_widgets.dart';

/// Statistiche tab: the six ability scores plus saving-throw and skill
/// proficiency/expertise toggles. Reads (never writes) `abilityMod` /
/// `skillBonus` / `savingThrowBonus`, which already lived on [Character]
/// before this split.
class StatisticheTab extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const StatisticheTab({super.key, required this.character, required this.onChanged});

  @override
  State<StatisticheTab> createState() => _StatisticheTabState();
}

class _StatisticheTabState extends State<StatisticheTab> {
  late final TextEditingController _str;
  late final TextEditingController _dex;
  late final TextEditingController _con;
  late final TextEditingController _int;
  late final TextEditingController _wis;
  late final TextEditingController _cha;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _str = TextEditingController(text: c.strength.toString());
    _dex = TextEditingController(text: c.dexterity.toString());
    _con = TextEditingController(text: c.constitution.toString());
    _int = TextEditingController(text: c.intelligence.toString());
    _wis = TextEditingController(text: c.wisdom.toString());
    _cha = TextEditingController(text: c.charisma.toString());
  }

  @override
  void dispose() {
    _str.dispose();
    _dex.dispose();
    _con.dispose();
    _int.dispose();
    _wis.dispose();
    _cha.dispose();
    super.dispose();
  }

  void _edit(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Punteggi Caratteristica'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatBox(
                label: 'FOR',
                controller: _str,
                modifier: fmtMod(c.strMod),
                base: c.nudeAbilityScore('str'),
                effective: c.effectiveAbilityScore('str'),
                onChanged: (v) => _edit(() => c.strength = int.tryParse(v) ?? 10),
              ),
              _StatBox(
                label: 'DES',
                controller: _dex,
                modifier: fmtMod(c.dexMod),
                base: c.nudeAbilityScore('dex'),
                effective: c.effectiveAbilityScore('dex'),
                onChanged: (v) => _edit(() => c.dexterity = int.tryParse(v) ?? 10),
              ),
              _StatBox(
                label: 'COS',
                controller: _con,
                modifier: fmtMod(c.conMod),
                base: c.nudeAbilityScore('con'),
                effective: c.effectiveAbilityScore('con'),
                onChanged: (v) => _edit(() => c.constitution = int.tryParse(v) ?? 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatBox(
                label: 'INT',
                controller: _int,
                modifier: fmtMod(c.intMod),
                base: c.nudeAbilityScore('int'),
                effective: c.effectiveAbilityScore('int'),
                onChanged: (v) => _edit(() => c.intelligence = int.tryParse(v) ?? 10),
              ),
              _StatBox(
                label: 'SAG',
                controller: _wis,
                modifier: fmtMod(c.wisMod),
                base: c.nudeAbilityScore('wis'),
                effective: c.effectiveAbilityScore('wis'),
                onChanged: (v) => _edit(() => c.wisdom = int.tryParse(v) ?? 10),
              ),
              _StatBox(
                label: 'CAR',
                controller: _cha,
                modifier: fmtMod(c.chaMod),
                base: c.nudeAbilityScore('cha'),
                effective: c.effectiveAbilityScore('cha'),
                onChanged: (v) => _edit(() => c.charisma = int.tryParse(v) ?? 10),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSavingThrows(c)),
              const SizedBox(width: 16),
              Expanded(child: _buildSkills(c)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingThrows(Character c) {
    const saves = [
      ('str', 'Forza'),
      ('dex', 'Destrezza'),
      ('con', 'Costituzione'),
      ('int', 'Intelligenza'),
      ('wis', 'Saggezza'),
      ('cha', 'Carisma'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tiri Salvezza'),
        const SizedBox(height: 4),
        ...saves.map((s) {
          final hasProf = c.savingThrowProfs.contains(s.$1);
          return _ProfRow(
            label: s.$2,
            bonus: c.savingThrowBonus(s.$1),
            hasProficiency: hasProf,
            trailing: EquipmentBadge(
              base: c.savingThrowBonusBase(s.$1),
              effective: c.savingThrowBonus(s.$1),
            ),
            onToggle: () => _edit(() {
              if (hasProf) {
                c.savingThrowProfs.remove(s.$1);
              } else {
                c.savingThrowProfs.add(s.$1);
              }
            }),
          );
        }),
      ],
    );
  }

  Widget _buildSkills(Character c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Abilità'),
        const SizedBox(height: 4),
        ...kSkills.map((skill) {
          final hasProf = c.skillProfs.contains(skill);
          final hasExp = c.skillExpertise.contains(skill);
          final ability = kSkillAbility[skill] ?? 'dex';
          return _ProfRow(
            label: '$skill (${abilityShort(ability)})',
            bonus: c.skillBonus(skill),
            hasProficiency: hasProf,
            hasExpertise: hasExp,
            trailing: EquipmentBadge(
              base: c.skillBonusBase(skill),
              effective: c.skillBonus(skill),
            ),
            onToggle: () => _edit(() {
              if (hasExp) {
                c.skillExpertise.remove(skill);
                c.skillProfs.remove(skill);
              } else if (hasProf) {
                c.skillExpertise.add(skill);
              } else {
                c.skillProfs.add(skill);
              }
            }),
          );
        }),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String modifier;
  final int base;
  final int effective;
  final ValueChanged<String> onChanged;

  const _StatBox({
    required this.label,
    required this.controller,
    required this.modifier,
    required this.base,
    required this.effective,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 4),
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(modifier, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const SizedBox(height: 4),
          EquipmentBadge(base: base, effective: effective),
        ],
      );
}

class _ProfRow extends StatelessWidget {
  final String label;
  final int bonus;
  final bool hasProficiency;
  final bool hasExpertise;
  final Widget? trailing;
  final VoidCallback onToggle;

  const _ProfRow({
    required this.label,
    required this.bonus,
    required this.hasProficiency,
    this.hasExpertise = false,
    this.trailing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: hasExpertise
                    ? const Icon(Icons.star, color: AppTheme.accent, size: 16)
                    : hasProficiency
                        ? const Icon(Icons.circle, color: AppTheme.accent, size: 10)
                        : const Icon(Icons.circle_outlined, color: AppTheme.onSurfaceMuted, size: 10),
              ),
              SizedBox(
                width: 26,
                child: Text(
                  bonus >= 0 ? '+$bonus' : '$bonus',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: hasProficiency ? AppTheme.accent : AppTheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: hasProficiency ? AppTheme.onSurface : AppTheme.onSurfaceMuted,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      );
}
