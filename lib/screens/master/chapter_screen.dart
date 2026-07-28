import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../models/session_screen.dart';
import '../../providers/campaign_provider.dart';

const _uuid = Uuid();

class ChapterScreen extends ConsumerStatefulWidget {
  final String campaignId;
  final String chapterId;

  const ChapterScreen({
    super.key,
    required this.campaignId,
    required this.chapterId,
  });

  @override
  ConsumerState<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends ConsumerState<ChapterScreen> {
  Future<void> _addScreen() async {
    final title = await _showTitleDialog(context, 'Nuova Scena');
    if (title == null || title.trim().isEmpty) return;
    final screens = ref.read(screenListProvider(widget.chapterId)).valueOrNull ?? [];
    final screen = SessionScreen(
      id: _uuid.v4(),
      chapterId: widget.chapterId,
      title: title.trim(),
      order: screens.length,
    );
    await ref.read(screenListProvider(widget.chapterId).notifier).add(screen);
  }

  @override
  Widget build(BuildContext context) {
    final screens = ref.watch(screenListProvider(widget.chapterId));
    final chapterAsync = ref.watch(chapterProvider(widget.chapterId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/campaigns/${widget.campaignId}'),
        ),
        title: chapterAsync.when(
          data: (c) => Text(c?.title ?? 'Capitolo non trovato'),
          loading: () => const Text('Caricamento...'),
          error: (_, __) => const Text('Errore'),
        ),
        actions: [
          // Play all screens in sequence
          if ((screens.valueOrNull?.isNotEmpty ?? false))
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Avvia Sessione',
              onPressed: () {
                final list = screens.valueOrNull ?? [];
                if (list.isNotEmpty) {
                  context.go('/campaigns/${widget.campaignId}/chapters/${widget.chapterId}/screens/${list.first.id}/play');
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addScreen,
        icon: const Icon(Icons.add),
        label: const Text('Nuova Scena'),
      ),
      body: screens.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) => list.isEmpty
            ? _buildEmpty()
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: list.length,
                onReorder: (oldIndex, newIndex) => ref
                    .read(screenListProvider(widget.chapterId).notifier)
                    .reorder(oldIndex, newIndex),
                itemBuilder: (_, i) => _ScreenTile(
                  key: ValueKey(list[i].id),
                  screen: list[i],
                  index: i + 1,
                  onEdit: () => context.go(
                    '/campaigns/${widget.campaignId}/chapters/${widget.chapterId}/screens/${list[i].id}/edit',
                  ),
                  onPlay: () => context.go(
                    '/campaigns/${widget.campaignId}/chapters/${widget.chapterId}/screens/${list[i].id}/play',
                  ),
                  onDelete: () => _deleteScreen(list[i]),
                  onRename: () => _renameScreen(list[i]),
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined, size: 56, color: AppTheme.onSurfaceMuted),
            const SizedBox(height: 12),
            const Text('Nessuna scena', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Aggiungi la prima scena del capitolo', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
          ],
        ),
      );

  Future<void> _deleteScreen(SessionScreen s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Scena'),
        content: Text('Eliminare "${s.title}"?\nTutti i componenti saranno eliminati.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: AppTheme.danger), child: const Text('Elimina')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(screenListProvider(widget.chapterId).notifier).delete(s.id);
    }
  }

  Future<void> _renameScreen(SessionScreen s) async {
    final title = await _showTitleDialog(context, 'Rinomina Scena', initial: s.title);
    if (title != null && title.trim().isNotEmpty) {
      s.title = title.trim();
      await ref.read(screenProvider(s.id).notifier).save(s);
    }
  }
}

Future<String?> _showTitleDialog(BuildContext context, String dialogTitle, {String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(dialogTitle),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(hintText: 'Titolo'),
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}

class _ScreenTile extends StatelessWidget {
  final SessionScreen screen;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _ScreenTile({
    super.key,
    required this.screen,
    required this.index,
    required this.onEdit,
    required this.onPlay,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onEdit,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.masterRed.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('$index', style: const TextStyle(color: AppTheme.masterRed, fontWeight: FontWeight.bold)),
          ),
        ),
        title: Text(screen.title, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: AppTheme.accent, size: 22),
              onPressed: onPlay,
              tooltip: 'Modalità Sessione',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.onSurfaceMuted, size: 20),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                const PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                const PopupMenuItem(value: 'delete', child: Text('Elimina', style: TextStyle(color: AppTheme.danger))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
