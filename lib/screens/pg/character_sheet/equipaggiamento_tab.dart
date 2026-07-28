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
