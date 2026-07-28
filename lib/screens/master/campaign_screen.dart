import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../models/campaign.dart';
import '../../models/chapter.dart';
import '../../providers/campaign_provider.dart';

const _uuid = Uuid();

class CampaignScreen extends ConsumerStatefulWidget {
  final String campaignId;
  const CampaignScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  bool _editingInfo = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _settingCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _settingCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _settingCtrl.dispose();
    super.dispose();
  }

  void _startEditing(Campaign campaign) {
    _nameCtrl.text = campaign.name;
    _descCtrl.text = campaign.description;
    _settingCtrl.text = campaign.setting;
    setState(() => _editingInfo = true);
  }

  Future<void> _saveInfo(Campaign campaign) async {
    campaign.name = _nameCtrl.text;
    campaign.description = _descCtrl.text;
    campaign.setting = _settingCtrl.text;
    campaign.updatedAt = DateTime.now();
    await ref.read(campaignProvider(widget.campaignId).notifier).save(campaign);
    if (mounted) setState(() => _editingInfo = false);
  }

  Future<void> _addChapter() async {
    final title = await _showTitleDialog(context, 'Nuovo Capitolo');
    if (title == null || title.trim().isEmpty) return;
    final chapters = ref.read(chapterListProvider(widget.campaignId)).valueOrNull ?? [];
    final chapter = Chapter(
      id: _uuid.v4(),
      campaignId: widget.campaignId,
      title: title.trim(),
      order: chapters.length,
    );
    await ref.read(chapterListProvider(widget.campaignId).notifier).add(chapter);
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(chapterListProvider(widget.campaignId));
    final campaignAsync = ref.watch(campaignProvider(widget.campaignId));
    final campaign = campaignAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/campaigns'),
        ),
        title: campaignAsync.when(
          data: (c) => Text(c?.name ?? 'Campagna non trovata'),
          loading: () => const Text('Caricamento...'),
          error: (_, __) => const Text('Errore'),
        ),
        actions: [
          IconButton(
            icon: Icon(_editingInfo ? Icons.check : Icons.edit_outlined),
            onPressed: campaign == null
                ? null
                : _editingInfo
                    ? () => _saveInfo(campaign)
                    : () => _startEditing(campaign),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addChapter,
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Capitolo'),
      ),
      body: Column(
        children: [
          campaignAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Errore: $e', style: const TextStyle(color: AppTheme.danger)),
            ),
            data: (c) {
              if (c == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Campagna non trovata', style: TextStyle(color: AppTheme.onSurfaceMuted)),
                );
              }
              return _editingInfo ? _buildEditInfo() : _buildCampaignInfo(c);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: chapters.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (list) => list.isEmpty
                  ? _buildEmptyChapters()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: list.length,
                      onReorder: (oldIndex, newIndex) => ref
                          .read(chapterListProvider(widget.campaignId).notifier)
                          .reorder(oldIndex, newIndex),
                      itemBuilder: (_, i) => _ChapterTile(
                        key: ValueKey(list[i].id),
                        chapter: list[i],
                        index: i + 1,
                        onTap: () => context.go('/campaigns/${widget.campaignId}/chapters/${list[i].id}'),
                        onDelete: () => _deleteChapter(list[i]),
                        onRename: () => _renameChapter(list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignInfo(Campaign campaign) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (campaign.setting.isNotEmpty) ...[
            Text(campaign.setting, style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
          ],
          if (campaign.description.isNotEmpty)
            Text(campaign.description, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEditInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surface,
      child: Column(
        children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome Campagna')),
          const SizedBox(height: 8),
          TextField(controller: _settingCtrl, decoration: const InputDecoration(labelText: 'Ambientazione')),
          const SizedBox(height: 8),
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descrizione'), maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildEmptyChapters() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.book_outlined, size: 56, color: AppTheme.onSurfaceMuted),
            const SizedBox(height: 12),
            const Text('Nessun capitolo', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Aggiungi il primo capitolo', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
          ],
        ),
      );

  Future<void> _deleteChapter(Chapter c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Capitolo'),
        content: Text('Eliminare "${c.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: AppTheme.danger), child: const Text('Elimina')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(chapterListProvider(widget.campaignId).notifier).delete(c.id);
    }
  }

  Future<void> _renameChapter(Chapter c) async {
    final title = await _showTitleDialog(context, 'Rinomina Capitolo', initial: c.title);
    if (title != null && title.trim().isNotEmpty) {
      c.title = title.trim();
      await ref.read(chapterProvider(c.id).notifier).save(c);
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

class _ChapterTile extends StatelessWidget {
  final Chapter chapter;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _ChapterTile({
    super.key,
    required this.chapter,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('$index', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ),
        title: Text(chapter.title, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
        subtitle: chapter.summary.isNotEmpty
            ? Text(chapter.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right, color: AppTheme.accent),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.onSurfaceMuted, size: 20),
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
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
