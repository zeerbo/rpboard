import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/character.dart';
import 'shared_widgets.dart';

/// Magie tab: the spellcasting-ability field, the derived spell save DC /
/// spell attack bonus display, the nine spell-slot rows, and the spell list.
///
/// The prepared-spell limit lives on [Character] too: the tab types it into
/// `preparedSpellsMax`, renders `preparedSpellsCount` against it as a third
/// chip, and lets [Character.togglePreparedSpell] decide whether a tap on a
/// spell's circle is allowed — showing a snack bar when it is refused.
///
/// `spellSaveDC`/`spellAttackBonus` are read straight from [Character] —
/// this is the PRD's headline fix, replacing the old inline
/// `substring(0,3)` shortcut that silently zeroed out every spellcasting
/// ability except Intelligenza. Spell-slot rows call [Character]'s
/// set-total/use/restore methods.
class MagieTab extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const MagieTab({super.key, required this.character, required this.onChanged});

  @override
  State<MagieTab> createState() => _MagieTabState();
}

class _MagieTabState extends State<MagieTab> {
  late final TextEditingController _spellcastingAbility;
  late final TextEditingController _preparedSpellsMax;

  @override
  void initState() {
    super.initState();
    _spellcastingAbility = TextEditingController(text: widget.character.spellcastingAbility);
    _preparedSpellsMax =
        TextEditingController(text: widget.character.preparedSpellsMax.toString());
  }

  @override
  void dispose() {
    _spellcastingAbility.dispose();
    _preparedSpellsMax.dispose();
    super.dispose();
  }

  void _edit(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  /// Flips a spell's prepared flag, or explains why it could not.
  ///
  /// [Character.togglePreparedSpell] owns the rule and reports its outcome;
  /// this only turns a refusal into a message. A refusal changes nothing, so
  /// it neither rebuilds nor marks the character dirty.
  ///
  /// The message is shown only while the limit is actually in force, so the
  /// tab never restates *which* taps the model refuses — a cantrip, whose
  /// toggle is already inert today and needs no explanation, stays silent
  /// without this screen carrying a second copy of the cantrip rule.
  void _togglePrepared(Character c, int index) {
    if (c.togglePreparedSpell(index)) {
      _edit(() {});
      return;
    }
    if (c.canPrepareAnotherSpell) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Limite incantesimi preparati raggiunto (${c.preparedSpellsMax})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Incantamento'),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _spellcastingAbility,
            label: 'Caratteristica Incantamento (es. Intelligenza)',
            onEdited: (v) => _edit(() => c.spellcastingAbility = v),
          ),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _preparedSpellsMax,
            label: 'Incantesimi Preparabili',
            numeric: true,
            // Clamped at zero because the shared numeric field's formatter
            // admits a leading minus sign. No upper bound: a limit is typed
            // digit by digit, so a ceiling would mangle the number mid-entry.
            onEdited: (v) => _edit(
              () => c.preparedSpellsMax = math.max(0, int.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            InfoChip('CD Magia', '${c.spellSaveDC}'),
            const SizedBox(width: 12),
            InfoChip('Bonus Attacco', '+${c.spellAttackBonus}'),
            // Hidden entirely at a limit of 0, where the limit is not in
            // force and the number would mean nothing.
            if (c.preparedSpellsMax > 0) ...[
              const SizedBox(width: 12),
              InfoChip(
                'Preparati',
                '${c.preparedSpellsCount}/${c.preparedSpellsMax}',
                valueColor: c.isOverPreparedLimit ? AppTheme.danger : AppTheme.accent,
              ),
            ],
          ]),
          if (c.spellDamageLabel() != null) ...[
            const SizedBox(height: 8),
            Text(
              'Danno Incantesimi: ${c.spellDamageLabel()}',
              style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          const SectionHeader(title: 'Slot Magia'),
          const SizedBox(height: 8),
          ...List.generate(9, (i) {
            final level = i + 1;
            final slot = c.spellSlots.where((s) => s.level == level).firstOrNull;
            return _SpellSlotRow(
              level: level,
              total: slot?.total ?? 0,
              used: slot?.used ?? 0,
              onTotalChange: (v) => _edit(() => c.setSpellSlotTotal(level, v)),
              onUse: () => _edit(() => c.useSpellSlot(level)),
              onRestore: () => _edit(() => c.restoreSpellSlot(level)),
            );
          }),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Incantesimi'),
          const SizedBox(height: 8),
          _buildSpellList(c),
        ],
      ),
    );
  }

  Widget _buildSpellList(Character c) {
    final byLevel = <int, List<MapEntry<int, Spell>>>{};
    for (int i = 0; i < c.spells.length; i++) {
      final s = c.spells[i];
      byLevel.putIfAbsent(s.level, () => []).add(MapEntry(i, s));
    }
    final sortedLevels = byLevel.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (byLevel.isEmpty)
          const Text('Nessun incantesimo', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
        ...sortedLevels.map((level) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                level == 0 ? 'Trucchetti' : 'Livello $level',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            ...byLevel[level]!.map((e) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: SizedBox(
                // A larger, invisible hit area around the 20px glyph. 40 is
                // the most this can grow to without shifting the title: a
                // ListTile already reserves `minLeadingWidth` (40 by
                // default) for the leading column regardless of how small
                // the leading widget actually is, so this claims space the
                // row already set aside rather than taking new space from
                // the title. `HitTestBehavior.opaque` makes the whole box
                // tappable, not just the glyph's own painted pixels, and
                // `Alignment.centerLeft` keeps the glyph itself exactly
                // where it was — same size, same position, same colours.
                width: 40,
                height: 40,
                child: GestureDetector(
                  key: ValueKey('spell_prepared_${e.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: level > 0 ? () => _togglePrepared(c, e.key) : null,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      e.value.prepared ? Icons.check_circle : Icons.circle_outlined,
                      color: e.value.prepared ? AppTheme.accent : AppTheme.onSurfaceMuted,
                      size: 20,
                    ),
                  ),
                ),
              ),
              title: Text(e.value.name, style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
              subtitle: Row(children: [
                if (e.value.school.isNotEmpty) Text('${e.value.school}  ', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                if (e.value.castingTime.isNotEmpty) Text(e.value.castingTime, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                if (e.value.damage.isNotEmpty) Text('  •  ${e.value.damage}', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
              ]),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                onPressed: () => _edit(() => c.spells.removeAt(e.key)),
              ),
            )),
          ],
        )),
        TextButton.icon(
          onPressed: () => _addSpell(c),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Aggiungi Incantesimo'),
        ),
      ],
    );
  }

  Future<void> _addSpell(Character c) async {
    final spell = await _showSpellDialog(Spell());
    if (spell != null) _edit(() => c.spells.add(spell));
  }

  Future<Spell?> _showSpellDialog(Spell initial) {
    final nam = TextEditingController(text: initial.name);
    final lvl = TextEditingController(text: initial.level.toString());
    final sch = TextEditingController(text: initial.school);
    final ct = TextEditingController(text: initial.castingTime);
    final rng = TextEditingController(text: initial.range);
    final cmp = TextEditingController(text: initial.components);
    final dur = TextEditingController(text: initial.duration);
    final desc = TextEditingController(text: initial.description);
    final dmg = TextEditingController(text: initial.damage);
    return showDialog<Spell>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Incantesimo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nam, decoration: const InputDecoration(labelText: 'Nome'), autofocus: true),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: lvl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Livello (0=trucchetto)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: sch, decoration: const InputDecoration(labelText: 'Scuola'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: ct, decoration: const InputDecoration(labelText: 'Tempo Lancio'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: rng, decoration: const InputDecoration(labelText: 'Gittata'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: cmp, decoration: const InputDecoration(labelText: 'Componenti'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: dur, decoration: const InputDecoration(labelText: 'Durata'))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrizione'), maxLines: 3),
              const SizedBox(height: 8),
              TextField(controller: dmg, decoration: const InputDecoration(labelText: 'Danno (es. 8d6 fuoco)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, Spell(name: nam.text, level: int.tryParse(lvl.text) ?? 0, school: sch.text, castingTime: ct.text, range: rng.text, components: cmp.text, duration: dur.text, description: desc.text, damage: dmg.text)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}

class _SpellSlotRow extends StatelessWidget {
  final int level;
  final int total;
  final int used;
  final ValueChanged<int> onTotalChange;
  final VoidCallback onUse;
  final VoidCallback onRestore;

  const _SpellSlotRow({
    required this.level,
    required this.total,
    required this.used,
    required this.onTotalChange,
    required this.onUse,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text('Lv.$level', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            ),
            SizedBox(
              width: 48,
              child: TextFormField(
                initialValue: total.toString(),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => onTotalChange(int.tryParse(v) ?? 0),
                style: const TextStyle(color: AppTheme.onSurface, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Tot',
                  contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (total > 0)
              Expanded(
                child: Row(
                  children: List.generate(
                    total.clamp(0, 9),
                    (i) => GestureDetector(
                      onTap: i < used ? onRestore : onUse,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          i < used ? Icons.circle_outlined : Icons.circle,
                          color: i < used ? AppTheme.onSurfaceMuted : AppTheme.accent,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}
