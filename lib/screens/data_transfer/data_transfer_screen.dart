import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_transport.dart';
import '../../core/sync/version_policy.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/data_transfer_provider.dart';
import 'import_confirmation_dialog.dart';

/// **Trasferisci dati** — the route named on the home screen by an icon
/// control, never a third mode card (`CONTEXT.md` keeps PG Mode and Master
/// Mode as the app's only two faces). Shows the exchange folder's path, an
/// export action, the archives found there with their envelope metadata,
/// and — through [ImportConfirmationDialog] — the confirmation gate before
/// an import.
class DataTransferScreen extends ConsumerWidget {
  const DataTransferScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dataTransferProvider.notifier).exportNow();
      messenger.showSnackBar(
        const SnackBar(content: Text('Esportazione completata.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Esportazione non riuscita: $e')),
      );
    }
  }

  Future<void> _pickArchive(
    BuildContext context,
    WidgetRef ref,
    ArchiveInfo archive,
    int localCharacterCount,
  ) async {
    final notifier = ref.read(dataTransferProvider.notifier);
    final outcome = notifier.evaluateVersion(archive);
    final refusalMessage =
        outcome == SchemaVersionOutcome.accepted ? '' : notifier.refusalMessageFor(archive);

    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ImportConfirmationDialog(
        localCharacterCount: localCharacterCount,
        archive: archive,
        outcome: outcome,
        refusalMessage: refusalMessage,
        onConfirm: () {},
      ),
    );

    if (confirmed != true) return;

    try {
      await notifier.importArchive(archive);
      messenger.showSnackBar(
        const SnackBar(content: Text('Importazione completata.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Importazione non riuscita: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(dataTransferProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trasferisci dati')),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Errore: $err')),
        data: (state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Cartella di scambio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            SelectableText(
              state.exchangeFolderPath,
              style: const TextStyle(
                  color: AppTheme.onSurfaceMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _export(context, ref),
              icon: const Icon(Icons.upload_file),
              label: const Text('Esporta'),
            ),
            const SizedBox(height: 24),
            Text(
              'Archivi trovati',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (state.archives.isEmpty)
              const Text(
                'Nessun archivio trovato in questa cartella.',
                style: TextStyle(color: AppTheme.onSurfaceMuted),
              )
            else
              ...state.archives.map(
                (archive) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(archive.envelope.exportedAt.toLocal().toString()),
                    subtitle: Text('Da: ${archive.envelope.deviceLabel}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickArchive(
                        context, ref, archive, state.localCharacterCount),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
