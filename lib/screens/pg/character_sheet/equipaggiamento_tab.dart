import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/character.dart';
import 'shared_widgets.dart';

/// Equipaggiamento tab: the five coin fields and the inventory list with its
/// add/edit/delete flow.
class EquipaggiamentoTab extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const EquipaggiamentoTab({super.key, required this.character, required this.onChanged});

  @override
  State<EquipaggiamentoTab> createState() => _EquipaggiamentoTabState();
}

class _EquipaggiamentoTabState extends State<EquipaggiamentoTab> {
  late final TextEditingController _cp;
  late final TextEditingController _sp;
  late final TextEditingController _ep;
  late final TextEditingController _gp;
  late final TextEditingController _pp;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _cp = TextEditingController(text: c.cp.toString());
    _sp = TextEditingController(text: c.sp.toString());
    _ep = TextEditingController(text: c.ep.toString());
    _gp = TextEditingController(text: c.gp.toString());
    _pp = TextEditingController(text: c.pp.toString());
  }

  @override
  void dispose() {
    _cp.dispose();
    _sp.dispose();
    _ep.dispose();
    _gp.dispose();
    _pp.dispose();
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
          const SectionHeader(title: 'Monete'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _CoinField(label: 'MR', controller: _cp, color: const Color(0xFFb87333), onChanged: (v) => _edit(() => c.cp = int.tryParse(v) ?? 0))),
            const SizedBox(width: 6),
            Expanded(child: _CoinField(label: 'MA', controller: _sp, color: Colors.grey, onChanged: (v) => _edit(() => c.sp = int.tryParse(v) ?? 0))),
            const SizedBox(width: 6),
            Expanded(child: _CoinField(label: 'ME', controller: _ep, color: const Color(0xFF4682b4), onChanged: (v) => _edit(() => c.ep = int.tryParse(v) ?? 0))),
            const SizedBox(width: 6),
            Expanded(child: _CoinField(label: 'MO', controller: _gp, color: AppTheme.accent, onChanged: (v) => _edit(() => c.gp = int.tryParse(v) ?? 0))),
            const SizedBox(width: 6),
            Expanded(child: _CoinField(label: 'MP', controller: _pp, color: Colors.white70, onChanged: (v) => _edit(() => c.pp = int.tryParse(v) ?? 0))),
          ]),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Oggetti Equipaggiati'),
          const SizedBox(height: 8),
          _buildEquipmentItems(c),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Inventario'),
          const SizedBox(height: 8),
          if (c.inventory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Inventario vuoto', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            ),
          ...c.inventory.asMap().entries.map((e) => Card(
            color: AppTheme.surfaceVariant,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text('${e.value.quantity}× ${e.value.name}', style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
              subtitle: e.value.notes.isNotEmpty ? Text(e.value.notes, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.value.weight > 0)
                    Text('${e.value.weight}kg', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                  const SizedBox(width: 4),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent), onPressed: () => _editInventoryItem(c, e.key)),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), onPressed: () => _edit(() => c.inventory.removeAt(e.key))),
                ],
              ),
            ),
          )),
          TextButton.icon(
            onPressed: () => _addInventoryItem(c),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi Oggetto'),
          ),
        ],
      ),
    );
  }

  Future<void> _addInventoryItem(Character c) async {
    final result = await _showInventoryDialog(InventoryItem());
    if (result != null) _edit(() => c.inventory.add(result));
  }

  Future<void> _editInventoryItem(Character c, int idx) async {
    final result = await _showInventoryDialog(c.inventory[idx]);
    if (result != null) _edit(() => c.inventory[idx] = result);
  }

  Future<InventoryItem?> _showInventoryDialog(InventoryItem initial) {
    final nam = TextEditingController(text: initial.name);
    final qty = TextEditingController(text: initial.quantity.toString());
    final wt = TextEditingController(text: initial.weight > 0 ? initial.weight.toString() : '');
    final not = TextEditingController(text: initial.notes);
    return showDialog<InventoryItem>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Oggetto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nam, decoration: const InputDecoration(labelText: 'Nome'), autofocus: true),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantità'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: wt, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso (kg)'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: not, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, InventoryItem(name: nam.text, quantity: int.tryParse(qty.text) ?? 1, weight: double.tryParse(wt.text) ?? 0, notes: not.text)),
            child: const Text('Salva'),
          ),
        ],
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.value.bonuses.isEmpty ? 'Nessun bonus' : e.value.bonuses.map(_describeBonus).join('  •  '),
                  style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11),
                ),
                if (e.value.notes.isNotEmpty)
                  Text(e.value.notes, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
              ],
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
      case EquipmentBonusType.spellSaveDC:
        return 'CD Inc ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.spellAttack:
        return 'Att Inc ${b.value >= 0 ? "+" : ""}${b.value}';
      case EquipmentBonusType.spellDamage:
        return b.damageForm == EquipmentDamageForm.dice
            ? 'Danno Inc +${b.diceCount}d${b.die}'
            : 'Danno Inc ${b.value >= 0 ? "+" : ""}${b.value}';
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
    final not = TextEditingController(text: initial.notes);
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
                const SizedBox(height: 8),
                TextField(controller: not, decoration: const InputDecoration(labelText: 'Note')),
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
              onPressed: () => Navigator.pop(context, EquipmentItem(name: nam.text, notes: not.text, bonuses: bonuses)),
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
                  DropdownMenuItem(value: EquipmentBonusType.spellSaveDC, child: Text('CD Incantesimi')),
                  DropdownMenuItem(value: EquipmentBonusType.spellAttack, child: Text('Attacco Incantesimi')),
                  DropdownMenuItem(value: EquipmentBonusType.spellDamage, child: Text('Danno Incantesimi')),
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
              if (type == EquipmentBonusType.damage ||
                  type == EquipmentBonusType.spellDamage) ...[
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
                type == EquipmentBonusType.damage ||
                        type == EquipmentBonusType.spellDamage
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
}

class _CoinField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final ValueChanged<String> onChanged;

  const _CoinField({required this.label, required this.controller, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 2)),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      );
}
