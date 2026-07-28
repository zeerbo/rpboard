import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/component.dart';
import '../../../providers/campaign_provider.dart';
import 'components/component_view.dart';

const _uuid = Uuid();

IconData _iconFor(ComponentData data) {
  switch (data) {
    case NarrativeTextData(): return Icons.text_fields;
    case NpcStatBlockData(): return Icons.person_outline;
    case InitiativeTrackerData(): return Icons.format_list_numbered;
    case CustomTableData(): return Icons.table_chart_outlined;
    case ImageData(): return Icons.image_outlined;
    case UnknownComponentData(): return Icons.warning_amber_outlined;
  }
}

String _labelFor(ComponentData data) {
  switch (data) {
    case NarrativeTextData(): return 'Testo Narrativo';
    case NpcStatBlockData(): return 'Blocco Statistiche NPC';
    case InitiativeTrackerData(): return 'Tracker Iniziativa';
    case CustomTableData(): return 'Tabella';
    case ImageData(): return 'Immagine';
    case UnknownComponentData(rawType: final t): return t;
  }
}

class SessionEditScreen extends ConsumerStatefulWidget {
  final String screenId;
  final String chapterId;
  final String campaignId;

  const SessionEditScreen({
    super.key,
    required this.screenId,
    required this.chapterId,
    required this.campaignId,
  });

  @override
  ConsumerState<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends ConsumerState<SessionEditScreen> {
  Future<void> _addComponent(ComponentData data) async {
    final components = ref.read(componentListProvider(widget.screenId)).valueOrNull ?? [];
    final comp = SessionComponent(
      id: _uuid.v4(),
      screenId: widget.screenId,
      order: components.length,
      data: data,
    );
    await ref.read(componentListProvider(widget.screenId).notifier).add(comp);
  }

  @override
  Widget build(BuildContext context) {
    final components = ref.watch(componentListProvider(widget.screenId));
    final screenAsync = ref.watch(screenProvider(widget.screenId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/campaigns/${widget.campaignId}/chapters/${widget.chapterId}'),
        ),
        title: screenAsync.when(
          data: (s) => Text(s?.title ?? 'Scena non trovata'),
          loading: () => const Text('Caricamento...'),
          error: (_, __) => const Text('Errore'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Modalità Sessione',
            onPressed: () => context.go(
              '/campaigns/${widget.campaignId}/chapters/${widget.chapterId}/screens/${widget.screenId}/play',
            ),
          ),
        ],
      ),
      body: components.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) => list.isEmpty
            ? _buildEmpty()
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: list.length,
                onReorder: (oldIndex, newIndex) => ref
                    .read(componentListProvider(widget.screenId).notifier)
                    .reorder(oldIndex, newIndex),
                itemBuilder: (_, i) => _ComponentCard(
                  key: ValueKey(list[i].id),
                  component: list[i],
                  onDelete: () => _deleteComponent(list[i].id),
                  onUpdate: (updated) => ref.read(componentListProvider(widget.screenId).notifier).save(updated),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.widgets_outlined, size: 56, color: AppTheme.onSurfaceMuted),
            const SizedBox(height: 12),
            const Text('Scena vuota', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Aggiungi componenti alla scena', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi Componente'),
            ),
          ],
        ),
      );

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aggiungi Componente', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ...ComponentData.kinds.map((k) => ListTile(
              leading: Icon(_iconFor(k.empty()), color: AppTheme.accent),
              title: Text(_labelFor(k.empty()), style: const TextStyle(color: AppTheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _addComponent(k.empty());
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteComponent(String id) async {
    await ref.read(componentListProvider(widget.screenId).notifier).delete(id);
  }
}

class _ComponentCard extends StatelessWidget {
  final SessionComponent component;
  final VoidCallback onDelete;
  final Future<void> Function(SessionComponent) onUpdate;

  const _ComponentCard({
    super.key,
    required this.component,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: AppTheme.onSurfaceMuted, size: 18),
                const SizedBox(width: 8),
                Text(_labelFor(component.data), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 12)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          // Component content
          Padding(
            padding: const EdgeInsets.all(12),
            child: ComponentView(component: component, isEditMode: true, onUpdate: onUpdate),
          ),
        ],
      ),
    );
  }
}
