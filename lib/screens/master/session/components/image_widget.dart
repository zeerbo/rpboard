import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/component.dart';

class ImageWidget extends StatelessWidget {
  final SessionComponent component;
  final bool isEditMode;
  final Future<void> Function(SessionComponent) onUpdate;

  const ImageWidget({
    super.key,
    required this.component,
    required this.isEditMode,
    required this.onUpdate,
  });

  ImageData get _data => component.data as ImageData;

  @override
  Widget build(BuildContext context) {
    final title = _data.title;
    final path = _data.path;
    final caption = _data.caption;
    final previewHeight = isEditMode ? 120.0 : 260.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: isEditMode ? 14 : 16),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          height: previewHeight,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
          ),
          child: path.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, size: 40, color: AppTheme.onSurfaceMuted),
                    Text('Nessuna immagine', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    path,
                    fit: isEditMode ? BoxFit.cover : BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: AppTheme.onSurfaceMuted),
                    ),
                  ),
                ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(caption, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11, fontStyle: FontStyle.italic)),
          ),
        if (isEditMode)
          TextButton.icon(
            onPressed: () => _editImage(context),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Modifica'),
          ),
      ],
    );
  }

  Future<void> _editImage(BuildContext context) async {
    final titleCtrl = TextEditingController(text: _data.title);
    final pathCtrl = TextEditingController(text: _data.path);
    final captionCtrl = TextEditingController(text: _data.caption);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Immagine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titolo')),
            const SizedBox(height: 8),
            TextField(controller: pathCtrl, decoration: const InputDecoration(labelText: 'Percorso file')),
            const SizedBox(height: 8),
            TextField(controller: captionCtrl, decoration: const InputDecoration(labelText: 'Didascalia')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              _data.title = titleCtrl.text;
              _data.path = pathCtrl.text;
              _data.caption = captionCtrl.text;
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
