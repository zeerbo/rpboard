import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/component.dart';

class NarrativeWidget extends StatefulWidget {
  final SessionComponent component;
  final bool isEditMode;
  final Future<void> Function(SessionComponent) onUpdate;

  const NarrativeWidget({
    super.key,
    required this.component,
    required this.isEditMode,
    required this.onUpdate,
  });

  @override
  State<NarrativeWidget> createState() => _NarrativeWidgetState();
}

class _NarrativeWidgetState extends State<NarrativeWidget> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  bool _editing = false;

  NarrativeTextData get _data => widget.component.data as NarrativeTextData;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: _data.title);
    _contentCtrl = TextEditingController(text: _data.content);
    if (widget.isEditMode && _contentCtrl.text.isEmpty) {
      _editing = true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _data.title = _titleCtrl.text;
    _data.content = _contentCtrl.text;
    await widget.onUpdate(widget.component);
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Titolo (opzionale)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentCtrl,
            decoration: const InputDecoration(
              labelText: 'Testo narrativo',
              alignLabelWithHint: true,
            ),
            maxLines: null,
            minLines: 4,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_contentCtrl.text.isEmpty) ...[
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Salva'),
              ),
            ],
          ),
        ],
      );
    }

    final title = _data.title;
    final content = _data.content;

    return GestureDetector(
      onTap: widget.isEditMode ? () => setState(() => _editing = true) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: widget.isEditMode
            ? BoxDecoration(
                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              content.isEmpty ? '(tocca per modificare)' : content,
              style: TextStyle(
                color: content.isEmpty ? AppTheme.onSurfaceMuted : AppTheme.onSurface,
                fontSize: 14,
                height: 1.5,
                fontStyle: content.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            if (widget.isEditMode && content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Modifica', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
