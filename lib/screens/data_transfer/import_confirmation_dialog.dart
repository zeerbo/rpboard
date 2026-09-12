import 'package:flutter/material.dart';

import '../../core/sync/sync_transport.dart';
import '../../core/sync/version_policy.dart';

/// The last thing between the user and losing their local Characters, so it
/// is built and tested as a first-class widget rather than treated as
/// chrome (see the data-transfer PRD's "Testing Decisions").
///
/// Shown for one [archive] the user picked from the Trasferisci dati
/// screen's list, together with the version-policy [outcome] already
/// computed for it. When [outcome] is
/// [SchemaVersionOutcome.accepted] the dialog states plainly that import
/// **replaces** local state and names the Character count on both sides;
/// otherwise it shows [refusalMessage] and offers no import affordance at
/// all — an incompatible archive never gets as far as a confirm button.
class ImportConfirmationDialog extends StatelessWidget {
  final int localCharacterCount;
  final ArchiveInfo archive;
  final SchemaVersionOutcome outcome;
  final String refusalMessage;
  final VoidCallback onConfirm;

  const ImportConfirmationDialog({
    super.key,
    required this.localCharacterCount,
    required this.archive,
    required this.outcome,
    required this.refusalMessage,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    if (outcome != SchemaVersionOutcome.accepted) {
      return AlertDialog(
        title: const Text('Archivio non compatibile'),
        content: Text(refusalMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Chiudi'),
          ),
        ],
      );
    }

    final envelope = archive.envelope;
    final archiveCharacterCount = envelope.snapshot.characters.length;

    return AlertDialog(
      title: const Text('Importa dati'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "L'importazione sostituirà i dati locali con quelli "
            "dell'archivio. Questa operazione non può essere annullata.",
          ),
          const SizedBox(height: 16),
          Text('Personaggi locali: $localCharacterCount'),
          Text('Personaggi nell\'archivio: $archiveCharacterCount'),
          const SizedBox(height: 16),
          Text('Esportato il: ${envelope.exportedAt.toLocal()}'),
          Text('Da: ${envelope.deviceLabel}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            onConfirm();
          },
          child: const Text('Importa'),
        ),
      ],
    );
  }
}
