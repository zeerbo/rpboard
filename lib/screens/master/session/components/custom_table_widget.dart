import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/component.dart';

class CustomTableWidget extends StatelessWidget {
  final SessionComponent component;
  final bool isEditMode;
  final Future<void> Function(SessionComponent) onUpdate;

  const CustomTableWidget({
    super.key,
    required this.component,
    required this.isEditMode,
    required this.onUpdate,
  });

  CustomTableData get _data => component.data as CustomTableData;

  @override
  Widget build(BuildContext context) {
    final title = _data.title;
    final headers = _data.headers;
    final rows = _data.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
        ],
        if (headers.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tabella non configurata',
                style: TextStyle(color: AppTheme.onSurfaceMuted, fontStyle: FontStyle.italic),
              ),
              if (isEditMode) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => _editTable(context),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Configura Tabella'),
                ),
              ],
            ],
          )
        else
          Column(
            children: [
              Table(
                border: TableBorder.all(color: AppTheme.surfaceVariant),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: AppTheme.surfaceVariant),
                    children: headers.map((h) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(h, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                    )).toList(),
                  ),
                  ...rows.map((row) => TableRow(
                    children: List.generate(headers.length, (i) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(i < row.length ? row[i] : '', style: const TextStyle(color: AppTheme.onSurface)),
                    )),
                  )),
                ],
              ),
              if (isEditMode)
                TextButton.icon(
                  onPressed: () => _editTable(context),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifica Tabella'),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _editTable(BuildContext context) async {
    final titleCtrl = TextEditingController(text: _data.title);
    final headersCtrl = TextEditingController(
      text: _data.headers.join(', '),
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Configura Tabella'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titolo')),
            const SizedBox(height: 8),
            TextField(
              controller: headersCtrl,
              decoration: const InputDecoration(labelText: 'Colonne (separate da virgola)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              final headers = headersCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              _data.title = titleCtrl.text;
              _data.headers = headers;
              _data.rows = <List<String>>[];
              onUpdate(component);
              Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
