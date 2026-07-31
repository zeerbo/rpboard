import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/character.dart';
import 'shared_widgets.dart';

/// Combattimento tab: hit points (with heal/damage dialog), AC/initiative/
/// speed/hit-dice fields, death saves, and the attack list.
///
/// Death-save ticking/reset calls onto [Character]'s tick/reset methods, so
/// `isDead`/`isStable` are maintained the moment a player ticks a box —
/// there is no inline count math here anymore.
class CombattimentoTab extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const CombattimentoTab({super.key, required this.character, required this.onChanged});

  @override
  State<CombattimentoTab> createState() => _CombattimentoTabState();
}

class _CombattimentoTabState extends State<CombattimentoTab> {
  late final TextEditingController _hpMax;
  late final TextEditingController _hpCurrent;
  late final TextEditingController _hpTemp;
  late final TextEditingController _ac;
  late final TextEditingController _initiative;
  late final TextEditingController _speed;
  late final TextEditingController _hitDice;
  late final TextEditingController _hitDiceUsed;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _hpMax = TextEditingController(text: c.hpMax.toString());
    _hpCurrent = TextEditingController(text: c.hpCurrent.toString());
    _hpTemp = TextEditingController(text: c.hpTemp.toString());
    _ac = TextEditingController(text: c.armorClass.toString());
    _initiative = TextEditingController(text: c.initiativeBonus.toString());
    _speed = TextEditingController(text: c.speed.toString());
    _hitDice = TextEditingController(text: c.hitDice);
    _hitDiceUsed = TextEditingController(text: c.hitDiceUsed.toString());
  }

  @override
  void dispose() {
    _hpMax.dispose();
    _hpCurrent.dispose();
    _hpTemp.dispose();
    _ac.dispose();
    _initiative.dispose();
    _speed.dispose();
    _hitDice.dispose();
    _hitDiceUsed.dispose();
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
          const SectionHeader(title: 'Punti Ferita'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _hpMax,
                label: 'PF Massimi',
                numeric: true,
                onEdited: (v) => _edit(() => c.hpMax = int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _hpTemp,
                label: 'PF Temporanei',
                numeric: true,
                onEdited: (v) => _edit(() => c.hpTemp = int.tryParse(v) ?? 0),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              flex: 2,
              child: SheetTextField(
                controller: _hpCurrent,
                label: 'PF Attuali',
                numeric: true,
                onEdited: (v) => _edit(() => c.hpCurrent = int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _showHpDialog(c, heal: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Danno'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _showHpDialog(c, heal: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cura'),
            ),
          ]),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Statistiche Combattimento'),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetTextField(
                    controller: _ac,
                    label: 'CA',
                    numeric: true,
                    onEdited: (v) => _edit(() => c.armorClass = int.tryParse(v) ?? 10),
                  ),
                  const SizedBox(height: 4),
                  EquipmentBadge(
                    base: c.armorClassEffective - c.sumEquipmentBonus(EquipmentBonusType.ac),
                    effective: c.armorClassEffective,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetTextField(
                    controller: _initiative,
                    label: 'Iniziativa',
                    numeric: true,
                    onEdited: (v) => _edit(() => c.initiativeBonus = int.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 4),
                  EquipmentBadge(base: c.initiativeBonus, effective: c.initiativeEffective),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetTextField(
                    controller: _speed,
                    label: 'Velocità (m)',
                    numeric: true,
                    onEdited: (v) => _edit(() => c.speed = int.tryParse(v) ?? 30),
                  ),
                  const SizedBox(height: 4),
                  EquipmentBadge(base: c.speed, effective: c.speedEffective),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _hitDice,
                label: 'Dadi Vita (es. 1d10)',
                onEdited: (v) => _edit(() => c.hitDice = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: SheetTextField(
                controller: _hitDiceUsed,
                label: 'Usati',
                numeric: true,
                onEdited: (v) => _edit(() => c.hitDiceUsed = int.tryParse(v) ?? 0),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Armatura'),
          const SizedBox(height: 8),
          _buildArmor(c),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Oggetti Equipaggiati'),
          const SizedBox(height: 8),
          _buildEquipmentItems(c),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Tiri Salvezza Morte'),
          const SizedBox(height: 8),
          _buildDeathSaves(c),
          if (c.isDead || c.isStable) _buildDeathOutcome(c),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Attacchi'),
          const SizedBox(height: 8),
          _buildAttacks(c),
        ],
      ),
    );
  }

  Widget _buildDeathSaves(Character c) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Successi', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 12)),
              Row(
                children: List.generate(3, (i) => Checkbox(
                  value: c.deathSaveSuccesses > i,
                  activeColor: AppTheme.success,
                  onChanged: (_) => _edit(() => c.tickDeathSaveSuccess(i)),
                )),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Fallimenti', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 12)),
              Row(
                children: List.generate(3, (i) => Checkbox(
                  value: c.deathSaveFailures > i,
                  activeColor: AppTheme.danger,
                  onChanged: (_) => _edit(() => c.tickDeathSaveFailure(i)),
                )),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _edit(() => c.resetDeathSaves()),
          child: const Text('Reset', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  /// Sticky death outcome banner. Shown only when [Character.isDead] or
  /// [Character.isStable] is set; the button is the single UI path that
  /// un-sets those flags (via [Character.clearDeathOutcome]).
  Widget _buildDeathOutcome(Character c) {
    final dead = c.isDead;
    final color = dead ? AppTheme.danger : AppTheme.success;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(dead ? Icons.dangerous : Icons.favorite,
              color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dead ? 'Morto' : 'Stabile',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => _edit(() => c.clearDeathOutcome()),
            child: const Text('Cancella esito', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttacks(Character c) {
    return Column(
      children: [
        if (c.attacks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nessun attacco', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
          ),
        ...c.attacks.asMap().entries.map((e) {
          final hit = c.attackWithEquipment(e.value);
          final dmgLabel = c.equipmentDamageLabel();
          final hitText = hit.total != null
              ? '${hit.total! >= 0 ? "+" : ""}${hit.total}${hit.equip != 0 ? " (${hit.equip >= 0 ? "+" : ""}${hit.equip} equip.)" : ""}'
              : '${e.value.attackBonus}${hit.equip != 0 ? "  (${hit.equip >= 0 ? "+" : ""}${hit.equip} equip.)" : ""}';
          final dmgText = e.value.damage + (dmgLabel != null ? '  •  $dmgLabel equip.' : '');
          return Card(
            color: AppTheme.surfaceVariant,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(e.value.name, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                '$hitText  •  $dmgText${e.value.type.isNotEmpty ? "  ${e.value.type}" : ""}',
                style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent), onPressed: () => _editAttack(c, e.key)),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), onPressed: () => _edit(() => c.attacks.removeAt(e.key))),
                ],
              ),
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _addAttack(c),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Aggiungi Attacco'),
        ),
      ],
    );
  }

  /// Armatura section: a prominent chip with the final, derived AC
  /// ([Character.armorClassEffective]), plus the single armor slot itself —
  /// a summary card with edit/remove when set, an "Aggiungi Armatura" button
  /// when not. The manual CA field above ([_ac]) is untouched here; it stays
  /// the fallback [Character.armorClassEffective] uses when [Character.armor]
  /// is null.
  Widget _buildArmor(Character c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Text('${c.armorClassEffective}',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 32)),
              const Text('CA Finale',
                  style: TextStyle(
                      color: AppTheme.onSurfaceMuted,
                      fontSize: 11,
                      letterSpacing: 1.0)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (c.armor == null)
          TextButton.icon(
            onPressed: () => _addArmor(c),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi Armatura'),
          )
        else
          Card(
            color: AppTheme.surfaceVariant,
            margin: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              title: Text(c.armor!.name,
                  style: const TextStyle(
                      color: AppTheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              subtitle: Text(
                'CA base ${c.armor!.baseAc}  •  ${c.armor!.addsDex ? "+ Destrezza" : "CA fissa"}',
                style: const TextStyle(
                    color: AppTheme.onSurfaceMuted, fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppTheme.accent),
                    onPressed: () => _editArmor(c),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.danger),
                    onPressed: () => _edit(() => c.armor = null),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addArmor(Character c) async {
    final result = await _showArmorDialog(Armor());
    if (result != null) _edit(() => c.armor = result);
  }

  Future<void> _editArmor(Character c) async {
    final result = await _showArmorDialog(c.armor!);
    if (result != null) _edit(() => c.armor = result);
  }

  Future<Armor?> _showArmorDialog(Armor initial) {
    final nam = TextEditingController(text: initial.name);
    final bac = TextEditingController(text: initial.baseAc.toString());
    bool addsDex = initial.addsDex;
    return showDialog<Armor>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Armatura'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nam, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 8),
              TextField(
                controller: bac,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'CA Base'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Somma Destrezza alla CA / CA fissa', style: TextStyle(fontSize: 13)),
                value: addsDex,
                onChanged: (v) => setDialogState(() => addsDex = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                Armor(name: nam.text, baseAc: int.tryParse(bac.text) ?? 10, addsDex: addsDex),
              ),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  /// Oggetti Equipaggiati: items distinct from the single armor slot above
  /// (rings, cloaks, amulets…), each carrying its own list of configurable
  /// bonuses. Mirrors the attacks list pattern (Card/ListTile + edit/delete).
  Widget _buildEquipmentItems(Character c) {
    return Column(
      children: [
        if (c.equipment.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nessun oggetto equipaggiato', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
          ),
        ...c.equipment.asMap().entries.map((e) => Card(
          color: AppTheme.surfaceVariant,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: Text(e.value.name, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              e.value.bonuses.isEmpty ? 'Nessun bonus' : e.value.bonuses.map(_describeBonus).join('  •  '),
              style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent), onPressed: () => _editEquipmentItem(c, e.key)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), onPressed: () => _edit(() => c.equipment.removeAt(e.key))),
              ],
            ),
          ),
        )),
        TextButton.icon(
          onPressed: () => _addEquipmentItem(c),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Aggiungi Oggetto'),
        ),
      ],
    );
  }

  /// Short display label for a single bonus. `ac`, `attack`, `damage`,
  /// `initiative` and `speed` are meaningful as of this ticket; later
  /// tickets add cases here for the remaining bonus types as they wire each
  /// one up.
  String _describeBonus(EquipmentBonus b) {
    switch (b.type) {
      case EquipmentBonusType.ac:
        return 'CA ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.attack:
        return 'Colpire ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.damage:
        return b.damageForm == EquipmentDamageForm.dice
            ? 'Danno +${b.diceCount}d${b.die}'
            : 'Danno ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.initiative:
        return 'Iniziativa ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.speed:
        return 'Velocità ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.savingThrow:
        return 'TS ${_targetLabel(b.target)} ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.ability:
        return '${_targetLabel(b.target)} ${b.value >= 0 ? "+" : ""}${b.value}';
    }
  }

  /// Human label for a bonus target key ('all' or a six-ability short key).
  String _targetLabel(String target) =>
      target == 'all' ? 'Tutti' : abilityShort(target);

  Future<void> _addEquipmentItem(Character c) async {
    final result = await _showEquipmentItemDialog(EquipmentItem());
    if (result != null) _edit(() => c.equipment.add(result));
  }

  Future<void> _editEquipmentItem(Character c, int idx) async {
    final result = await _showEquipmentItemDialog(c.equipment[idx]);
    if (result != null) _edit(() => c.equipment[idx] = result);
  }

  /// Item dialog: a name field plus a locally-managed working copy of the
  /// item's bonus list (add/edit/delete each bonus via [_showBonusDialog]).
  /// Nothing writes into [Character] until "Salva" is pressed.
  Future<EquipmentItem?> _showEquipmentItemDialog(EquipmentItem initial) {
    final nam = TextEditingController(text: initial.name);
    final bonuses = initial.bonuses
        .map((b) => EquipmentBonus(
              type: b.type,
              value: b.value,
              target: b.target,
              damageForm: b.damageForm,
              diceCount: b.diceCount,
              die: b.die,
            ))
        .toList();
    return showDialog<EquipmentItem>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Oggetto Equipaggiato'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nam, decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 12),
                const Text('Bonus', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (bonuses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Nessun bonus', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                  ),
                ...bonuses.asMap().entries.map((e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_describeBonus(e.value), style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent),
                        onPressed: () async {
                          final result = await _showBonusDialog(e.value);
                          if (result != null) setDialogState(() => bonuses[e.key] = result);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                        onPressed: () => setDialogState(() => bonuses.removeAt(e.key)),
                      ),
                    ],
                  ),
                )),
                TextButton.icon(
                  onPressed: () async {
                    final result = await _showBonusDialog(EquipmentBonus());
                    if (result != null) setDialogState(() => bonuses.add(result));
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Aggiungi Bonus'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, EquipmentItem(name: nam.text, bonuses: bonuses)),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  /// Bonus dialog: type selector plus sub-fields that react to the selected
  /// type (and, for `damage`, to the fixed/dice toggle). `ac` and `attack`
  /// both use a single integer value field; `damage` shows a fixed/dice
  /// toggle that swaps between a single value field and count+die fields.
  /// Tickets 04/05 extend the `items` list and add further conditional
  /// sub-fields (e.g. a target picker) in place, without restructuring this
  /// dialog.
  Future<EquipmentBonus?> _showBonusDialog(EquipmentBonus initial) {
    EquipmentBonusType type = initial.type;
    EquipmentDamageForm damageForm = initial.damageForm;
    // Target defaults to 'all' for the targeted types (savingThrow/ability)
    // when none is set yet; it's ignored for every other type.
    String target = initial.target.isEmpty ? 'all' : initial.target;
    final val = TextEditingController(text: initial.value.toString());
    final diceCount = TextEditingController(text: (initial.diceCount > 0 ? initial.diceCount : 1).toString());
    final die = TextEditingController(text: (initial.die > 0 ? initial.die : 6).toString());
    return showDialog<EquipmentBonus>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bonus'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<EquipmentBonusType>(
                value: type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: EquipmentBonusType.ac, child: Text('CA')),
                  DropdownMenuItem(value: EquipmentBonusType.attack, child: Text('Tiro per Colpire')),
                  DropdownMenuItem(value: EquipmentBonusType.damage, child: Text('Danno')),
                  DropdownMenuItem(value: EquipmentBonusType.initiative, child: Text('Iniziativa')),
                  DropdownMenuItem(value: EquipmentBonusType.speed, child: Text('Velocità')),
                  DropdownMenuItem(value: EquipmentBonusType.savingThrow, child: Text('Tiro Salvezza')),
                  DropdownMenuItem(value: EquipmentBonusType.ability, child: Text('Caratteristica')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? EquipmentBonusType.ac),
              ),
              const SizedBox(height: 8),
              if (type == EquipmentBonusType.savingThrow ||
                  type == EquipmentBonusType.ability) ...[
                DropdownButton<String>(
                  value: target,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tutti')),
                    DropdownMenuItem(value: 'str', child: Text('Forza')),
                    DropdownMenuItem(value: 'dex', child: Text('Destrezza')),
                    DropdownMenuItem(value: 'con', child: Text('Costituzione')),
                    DropdownMenuItem(value: 'int', child: Text('Intelligenza')),
                    DropdownMenuItem(value: 'wis', child: Text('Saggezza')),
                    DropdownMenuItem(value: 'cha', child: Text('Carisma')),
                  ],
                  onChanged: (v) => setDialogState(() => target = v ?? 'all'),
                ),
                const SizedBox(height: 8),
              ],
              if (type == EquipmentBonusType.damage) ...[
                SegmentedButton<EquipmentDamageForm>(
                  segments: const [
                    ButtonSegment(value: EquipmentDamageForm.fixed, label: Text('Fisso')),
                    ButtonSegment(value: EquipmentDamageForm.dice, label: Text('Dadi')),
                  ],
                  selected: {damageForm},
                  onSelectionChanged: (s) => setDialogState(() => damageForm = s.first),
                ),
                const SizedBox(height: 8),
                if (damageForm == EquipmentDamageForm.fixed)
                  TextField(
                    controller: val,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*$'))],
                    decoration: const InputDecoration(labelText: 'Valore'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: diceCount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Numero dadi'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: die,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Tipo dado (es. 8)'),
                        ),
                      ),
                    ],
                  ),
              ] else
                TextField(
                  controller: val,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*$'))],
                  decoration: const InputDecoration(labelText: 'Valore'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                type == EquipmentBonusType.damage
                    ? EquipmentBonus(
                        type: type,
                        value: damageForm == EquipmentDamageForm.fixed ? (int.tryParse(val.text) ?? 0) : 0,
                        damageForm: damageForm,
                        diceCount: damageForm == EquipmentDamageForm.dice ? (int.tryParse(diceCount.text) ?? 0) : 0,
                        die: damageForm == EquipmentDamageForm.dice ? (int.tryParse(die.text) ?? 0) : 0,
                      )
                    : EquipmentBonus(
                        type: type,
                        value: int.tryParse(val.text) ?? 0,
                        target: (type == EquipmentBonusType.savingThrow ||
                                type == EquipmentBonusType.ability)
                            ? target
                            : '',
                      ),
              ),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHpDialog(Character c, {required bool heal}) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(heal ? 'Cura PF' : 'Subisci Danno'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Quantità'),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
            child: Text(heal ? 'Cura' : 'Danno'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      _edit(() {
        if (heal) {
          c.hpCurrent = (c.hpCurrent + amount).clamp(0, c.hpMax);
        } else {
          c.hpCurrent = (c.hpCurrent - amount).clamp(0, c.hpMax);
        }
        _hpCurrent.text = c.hpCurrent.toString();
      });
    }
  }

  Future<void> _addAttack(Character c) async {
    final result = await _showAttackDialog(Attack());
    if (result != null) _edit(() => c.attacks.add(result));
  }

  Future<void> _editAttack(Character c, int idx) async {
    final result = await _showAttackDialog(c.attacks[idx]);
    if (result != null) _edit(() => c.attacks[idx] = result);
  }

  Future<Attack?> _showAttackDialog(Attack initial) {
    final nam = TextEditingController(text: initial.name);
    final bon = TextEditingController(text: initial.attackBonus);
    final dmg = TextEditingController(text: initial.damage);
    final typ = TextEditingController(text: initial.type);
    return showDialog<Attack>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Attacco'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nam, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 8),
            TextField(controller: bon, decoration: const InputDecoration(labelText: 'Bonus Attacco (es. +5)')),
            const SizedBox(height: 8),
            TextField(controller: dmg, decoration: const InputDecoration(labelText: 'Danno (es. 1d6+3)')),
            const SizedBox(height: 8),
            TextField(controller: typ, decoration: const InputDecoration(labelText: 'Tipo (es. tagliente)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, Attack(name: nam.text, attackBonus: bon.text, damage: dmg.text, type: typ.text)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
