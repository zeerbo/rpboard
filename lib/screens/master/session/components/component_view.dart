import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/component.dart';
import 'custom_table_widget.dart';
import 'image_widget.dart';
import 'initiative_tracker_widget.dart';
import 'narrative_widget.dart';
import 'npc_stat_block_widget.dart';

/// The single dispatch point for rendering a [SessionComponent]'s content.
///
/// Performs the one exhaustive switch over the sealed [ComponentData]
/// hierarchy to pick the per-kind widget. Both the edit screen and the play
/// screen call this for their content, wrapping it in their own chrome
/// (card, drag handle, kind label, delete button for the edit screen; the
/// play screen's own surrounding layout) — this widget renders content only.
class ComponentView extends StatelessWidget {
  final SessionComponent component;
  final bool isEditMode;
  final Future<void> Function(SessionComponent) onUpdate;

  const ComponentView({
    super.key,
    required this.component,
    required this.isEditMode,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    switch (component.data) {
      case NarrativeTextData():
        return NarrativeWidget(component: component, isEditMode: isEditMode, onUpdate: onUpdate);
      case NpcStatBlockData():
        return NpcStatBlockWidget(component: component, isEditMode: isEditMode, onUpdate: onUpdate);
      case InitiativeTrackerData():
        return InitiativeTrackerWidget(component: component, isEditMode: isEditMode, onUpdate: onUpdate);
      case CustomTableData():
        return CustomTableWidget(component: component, isEditMode: isEditMode, onUpdate: onUpdate);
      case ImageData():
        return ImageWidget(component: component, isEditMode: isEditMode, onUpdate: onUpdate);
      case UnknownComponentData(rawType: final t):
        return _UnsupportedComponentPlaceholder(rawType: t);
    }
  }
}

class _UnsupportedComponentPlaceholder extends StatelessWidget {
  final String rawType;

  const _UnsupportedComponentPlaceholder({required this.rawType});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: AppTheme.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Componente non supportato: $rawType',
                style: const TextStyle(color: AppTheme.onSurfaceMuted, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
}
