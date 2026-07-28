import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/component.dart';

const _uuid = Uuid();

class InitiativeTrackerWidget extends StatefulWidget {
  final SessionComponent component;
  final bool isEditMode;
  final Future<void> Function(SessionComponent) onUpdate;

  const InitiativeTrackerWidget({
    super.key,
    required this.component,
    required this.isEditMode,
    required this.onUpdate,
  });

  @override
  State<InitiativeTrackerWidget> createState() => _InitiativeTrackerWidgetState();
}

class _InitiativeTrackerWidgetState extends State<InitiativeTrackerWidget> {
  InitiativeTrackerData get _typedData => widget.component.data as InitiativeTrackerData;

  List<Map<String, dynamic>> get _combatants =>
      List<Map<String, dynamic>>.from(_typedData.combatants);

  int get _round => _typedData.round;
  int get _currentTurn => _typedData.currentTurn;

  void _update({List<Map<String, dynamic>>? combatants, int? round, int? currentTurn}) {
    final data = _typedData;
    if (combatants != null) data.combatants = combatants;
    if (round != null) data.round = round;
    if (currentTurn != null) data.currentTurn = currentTurn;
    widget.onUpdate(widget.component);
  }

  void _nextTurn() {
    final list = _combatants;
    if (list.isEmpty) return;
    int next = _currentTurn + 1;
    int round = _round;
    if (next >= list.length) {
      next = 0;
      round++;
    }
    _update(round: round, currentTurn: next);
    setState(() {});
  }

  void _prevTurn() {
    final list = _combatants;
    if (list.isEmpty) return;
    int prev = _currentTurn - 1;
    int round = _round;
    if (prev < 0) {
      prev = list.length - 1;
      round = max(1, round - 1);
    }
    _update(round: round, currentTurn: prev);
    setState(() {});
  }

  void _resetCombat() {
    _update(round: 1, currentTurn: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final combatants = _combatants;
    final sortedCombatants = [...combatants]..sort((a, b) =>
        ((b['initiative'] as num?)?.toInt() ?? 0).compareTo((a['initiative'] as num?)?.toInt() ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Round + navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                ),
                child: Text('Round $_round', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const Spacer(),
              if (combatants.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: AppTheme.onSurface),
                  onPressed: _prevTurn,
                  tooltip: 'Turno precedente',
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: AppTheme.accent),
                  onPressed: _nextTurn,
                  tooltip: 'Turno successivo',
                ),
              ],
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.onSurfaceMuted),
                onPressed: _resetCombat,
                tooltip: 'Ricomincia',
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Combatant list
        if (combatants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.shield_outlined, size: 40, color: AppTheme.onSurfaceMuted),
                  const SizedBox(height: 8),
                  const Text('Nessun combattente', style: TextStyle(color: AppTheme.onSurfaceMuted)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _addCombatant(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Aggiungi'),
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedCombatants.asMap().entries.map((e) {
            final originalIndex = combatants.indexOf(e.value);
            final isCurrent = originalIndex == _currentTurn;
            return _CombatantRow(
              key: ValueKey(e.value['id']),
              combatant: e.value,
              isCurrent: isCurrent,
              isFirst: e.key == 0,
              onHpChange: (delta) {
                final list = _combatants;
                final c = list[originalIndex];
                final cur = (c['hp_current'] as num?)?.toInt() ?? 0;
                final max = (c['hp_max'] as num?)?.toInt() ?? 0;
                c['hp_current'] = (cur + delta).clamp(0, max);
                _update(combatants: list);
                setState(() {});
              },
              onDelete: () {
                final list = _combatants;
                list.removeAt(originalIndex);
                int turn = _currentTurn;
                if (turn >= list.length) turn = max(0, list.length - 1);
                _update(combatants: list, currentTurn: turn);
                setState(() {});
              },
              onEdit: () => _editCombatant(context, originalIndex),
            );
          }),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _addCombatant(context),
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Aggiungi Combattente'),
            ),
            if (combatants.isNotEmpty)
              TextButton.icon(
                onPressed: () => _rollAllInitiatives(context),
                icon: const Icon(Icons.casino, size: 16),
                label: const Text('Tira Iniziativa'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _addCombatant(BuildContext context) async {
    final result = await _showCombatantDialog(
      context,
      'Aggiungi Combattente',
      {'id': _uuid.v4(), 'name': '', 'initiative': 0, 'hp_max': 10, 'hp_current': 10, 'ac': 10, 'is_player': false, 'notes': ''},
    );
    if (result != null) {
      final list = _combatants;
      list.add(result);
      _update(combatants: list);
      setState(() {});
    }
  }

  Future<void> _editCombatant(BuildContext context, int index) async {
    final list = _combatants;
    final result = await _showCombatantDialog(context, 'Modifica Combattente', list[index]);
    if (result != null) {
      list[index] = result;
      _update(combatants: list);
      setState(() {});
    }
  }

  void _rollAllInitiatives(BuildContext context) {
    final rng = Random();
    final list = _combatants;
    for (final c in list) {
      c['initiative'] = rng.nextInt(20) + 1;
    }
    _update(combatants: list, currentTurn: 0, round: 1);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Iniziativa tirata per tutti i combattenti'), duration: Duration(seconds: 2)),
    );
  }

  Future<Map<String, dynamic>?> _showCombatantDialog(
    BuildContext context,
    String title,
    Map<String, dynamic> initial,
  ) {
    final nameCtrl = TextEditingController(text: initial['name'] as String? ?? '');
    final initCtrl = TextEditingController(text: (initial['initiative'] ?? 0).toString());
    final hpMaxCtrl = TextEditingController(text: (initial['hp_max'] ?? 10).toString());
    final hpCurCtrl = TextEditingController(text: (initial['hp_current'] ?? 10).toString());
    final acCtrl = TextEditingController(text: (initial['ac'] ?? 10).toString());
    final notesCtrl = TextEditingController(text: initial['notes'] as String? ?? '');
    bool isPlayer = initial['is_player'] as bool? ?? false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setS) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome'), autofocus: true),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: initCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))], decoration: const InputDecoration(labelText: 'Iniziativa'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: acCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'CA'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: hpMaxCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'PF Max'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: hpCurCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'PF Attuali'))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Note')),
              const SizedBox(height: 8),
              Row(children: [
                Checkbox(value: isPlayer, onChanged: (v) => setS(() => isPlayer = v ?? false)),
                const Text('Giocatore (PG)', style: TextStyle(color: AppTheme.onSurface)),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'id': initial['id'] ?? _uuid.v4(),
                'name': nameCtrl.text,
                'initiative': int.tryParse(initCtrl.text) ?? 0,
                'hp_max': int.tryParse(hpMaxCtrl.text) ?? 10,
                'hp_current': int.tryParse(hpCurCtrl.text) ?? 10,
                'ac': int.tryParse(acCtrl.text) ?? 10,
                'is_player': isPlayer,
                'notes': notesCtrl.text,
              }),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombatantRow extends StatelessWidget {
  final Map<String, dynamic> combatant;
  final bool isCurrent;
  final bool isFirst;
  final void Function(int delta) onHpChange;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CombatantRow({
    super.key,
    required this.combatant,
    required this.isCurrent,
    required this.isFirst,
    required this.onHpChange,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final name = combatant['name'] as String? ?? '';
    final initiative = (combatant['initiative'] as num?)?.toInt() ?? 0;
    final hpMax = (combatant['hp_max'] as num?)?.toInt() ?? 0;
    final hpCur = (combatant['hp_current'] as num?)?.toInt() ?? 0;
    final ac = (combatant['ac'] as num?)?.toInt() ?? 10;
    final isPlayer = combatant['is_player'] as bool? ?? false;
    final notes = combatant['notes'] as String? ?? '';

    final hpRatio = hpMax > 0 ? hpCur / hpMax : 0.0;
    final hpColor = hpRatio <= 0
        ? AppTheme.danger
        : hpRatio <= 0.25
            ? AppTheme.danger
            : hpRatio <= 0.5
                ? AppTheme.warning
                : AppTheme.success;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.accent.withOpacity(0.1) : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? AppTheme.accent : (isPlayer ? AppTheme.accent.withOpacity(0.3) : AppTheme.masterRed.withOpacity(0.3)),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Initiative bubble
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPlayer ? AppTheme.accent.withOpacity(0.2) : AppTheme.masterRed.withOpacity(0.2),
                    border: Border.all(color: isPlayer ? AppTheme.accent : AppTheme.masterRed),
                  ),
                  child: Center(
                    child: Text(
                      '$initiative',
                      style: TextStyle(
                        color: isPlayer ? AppTheme.accent : AppTheme.masterRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isCurrent)
                            const Icon(Icons.arrow_right, color: AppTheme.accent, size: 16),
                          Text(
                            name,
                            style: TextStyle(
                              color: isCurrent ? AppTheme.accent : AppTheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('CA $ac', style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                          if (isPlayer)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('PG', style: TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      if (notes.isNotEmpty)
                        Text(notes, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11)),
                    ],
                  ),
                ),
                // HP controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showHpDialog(context, heal: false),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.remove, color: AppTheme.danger, size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      children: [
                        Text(
                          '$hpCur/$hpMax',
                          style: TextStyle(color: hpColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Text('PF', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 9)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _showHpDialog(context, heal: true),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.add, color: AppTheme.success, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.onSurfaceMuted, size: 18),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                    const PopupMenuItem(value: 'delete', child: Text('Rimuovi', style: TextStyle(color: AppTheme.danger))),
                  ],
                ),
              ],
            ),
            if (hpMax > 0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: hpRatio.clamp(0.0, 1.0),
                backgroundColor: AppTheme.surface,
                color: hpColor,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showHpDialog(BuildContext context, {required bool heal}) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(heal ? 'Cura' : 'Danno'),
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
      onHpChange(heal ? amount : -amount);
    }
  }
}
