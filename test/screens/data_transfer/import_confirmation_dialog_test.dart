import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/core/sync/sync_transport.dart';
import 'package:rpboard/core/sync/version_policy.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/screens/data_transfer/import_confirmation_dialog.dart';

/// Widget tests for [ImportConfirmationDialog] — the last thing between the
/// user and losing their local Characters. Prior art:
/// `test/screens/master/session/components/component_view_test.dart`.
void main() {
  ArchiveInfo archiveWith({
    required int characterCount,
    required DateTime exportedAt,
    required String deviceLabel,
    int schemaVersion = 4,
  }) {
    final characters = List.generate(
      characterCount,
      (i) => Character(id: 'c$i', name: 'Character $i'),
    );
    return ArchiveInfo(
      path: '/fake/archive.json',
      envelope: SnapshotEnvelope(
        formatVersion: 1,
        schemaVersion: schemaVersion,
        appVersion: '1.0.0+1',
        exportedAt: exportedAt,
        deviceLabel: deviceLabel,
        snapshot: AppSnapshot(characters: characters),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required int localCharacterCount,
    required ArchiveInfo archive,
    SchemaVersionOutcome outcome = SchemaVersionOutcome.accepted,
    String refusalMessage = '',
    VoidCallback? onConfirm,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImportConfirmationDialog(
            localCharacterCount: localCharacterCount,
            archive: archive,
            outcome: outcome,
            refusalMessage: refusalMessage,
            onConfirm: onConfirm ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows the local and archive Character counts', (tester) async {
    final archive = archiveWith(
      characterCount: 3,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'DESKTOP-ONE',
    );

    await pump(tester, localCharacterCount: 5, archive: archive);

    expect(find.textContaining('5'), findsWidgets);
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('shows the archive\'s export timestamp and device label', (tester) async {
    final archive = archiveWith(
      characterCount: 1,
      exportedAt: DateTime(2026, 3, 15),
      deviceLabel: 'THE-OTHER-MACHINE',
    );

    await pump(tester, localCharacterCount: 0, archive: archive);

    expect(find.textContaining('THE-OTHER-MACHINE'), findsOneWidget);
    expect(find.textContaining('2026'), findsWidgets);
  });

  testWidgets('states plainly that import replaces local data', (tester) async {
    final archive = archiveWith(
      characterCount: 1,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'x',
    );

    await pump(tester, localCharacterCount: 0, archive: archive);

    expect(find.textContaining('sostituirà'), findsOneWidget);
  });

  testWidgets('cancelling calls no confirmation callback', (tester) async {
    final archive = archiveWith(
      characterCount: 1,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'x',
    );
    var confirmed = false;

    await pump(
      tester,
      localCharacterCount: 0,
      archive: archive,
      onConfirm: () => confirmed = true,
    );
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
  });

  testWidgets('confirming calls the confirmation callback exactly once', (tester) async {
    final archive = archiveWith(
      characterCount: 1,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'x',
    );
    var confirmCount = 0;

    await pump(
      tester,
      localCharacterCount: 0,
      archive: archive,
      onConfirm: () => confirmCount++,
    );
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();

    expect(confirmCount, 1);
  });

  testWidgets(
      'a higher schemaVersion surfaces the update-this-installation message, '
      'not an import affordance', (tester) async {
    final archive = archiveWith(
      characterCount: 1,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'x',
      schemaVersion: 99,
    );

    await pump(
      tester,
      localCharacterCount: 0,
      archive: archive,
      outcome: SchemaVersionOutcome.refusedNewer,
      refusalMessage: 'Aggiorna questa installazione prima di importarlo.',
    );

    expect(find.text('Importa'), findsNothing);
    expect(find.textContaining('Aggiorna'), findsOneWidget);
  });
}
