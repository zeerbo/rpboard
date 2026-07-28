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
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _ac,
                label: 'CA',
                numeric: true,
                onEdited: (v) => _edit(() => c.armorClass = int.tryParse(v) ?? 10),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _initiative,
                label: 'Iniziativa',
                numeric: true,
                onEdited: (v) => _edit(() => c.initiativeBonus = int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _speed,
                label: 'Velocità (m)',
                numeric: true,
                onEdited: (v) => _edit(() => c.speed = int.tryParse(v) ?? 30),
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
        ...c.attacks.asMap().entries.map((e) => Card(
          color: AppTheme.surfaceVariant,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: Text(e.value.name, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text(
              '${e.value.attackBonus}  •  ${e.value.damage}${e.value.type.isNotEmpty ? "  ${e.value.type}" : ""}',
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
        )),
        TextButton.icon(
          onPressed: () => _addAttack(c),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Aggiungi Attacco'),
        ),
      ],
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
