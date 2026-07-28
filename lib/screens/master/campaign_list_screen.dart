import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../models/campaign.dart';
import '../../providers/campaign_provider.dart';

const _uuid = Uuid();

class CampaignListScreen extends ConsumerWidget {
  const CampaignListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campagne'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCampaign(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuova Campagna'),
      ),
      body: campaigns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) => list.isEmpty
            ? _EmptyState(onTap: () => _createCampaign(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CampaignTile(
                  campaign: list[i],
                  onTap: () => context.go('/campaigns/${list[i].id}'),
                  onDelete: () => _deleteCampaign(context, ref, list[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _createCampaign(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context);
    if (name == null || name.trim().isEmpty) return;
    final now = DateTime.now();
    final c = Campaign(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(campaignListProvider.notifier).add(c);
    if (context.mounted) context.go('/campaigns/${c.id}');
  }

  Future<void> _deleteCampaign(
      BuildContext context, WidgetRef ref, Campaign c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Campagna'),
        content: Text('Eliminare "${c.name}"?\nTutti i capitoli e le sessioni saranno eliminati.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(campaignListProvider.notifier).delete(c.id);
    }
  }
}

Future<String?> _showNameDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Nuova Campagna'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(hintText: 'Nome della campagna'),
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Crea')),
      ],
    ),
  );
}

class _CampaignTile extends StatelessWidget {
  final Campaign campaign;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CampaignTile({required this.campaign, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.masterRed.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.masterRed.withOpacity(0.4)),
          ),
          child: const Icon(Icons.auto_stories, color: AppTheme.masterRed, size: 22),
        ),
        title: Text(campaign.name, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600)),
        subtitle: campaign.setting.isNotEmpty
            ? Text(campaign.setting, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12))
            : Text(
                'Aggiornata ${_fmtDate(campaign.updatedAt)}',
                style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right, color: AppTheme.masterRed),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.onSurfaceMuted, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined, size: 72, color: AppTheme.onSurfaceMuted),
            const SizedBox(height: 16),
            const Text('Nessuna campagna', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Crea la tua prima campagna', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: const Text('Crea Campagna'),
            ),
          ],
        ),
      );
}
