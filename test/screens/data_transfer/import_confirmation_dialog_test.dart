import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/core/sync/sync_transport.dart';
import 'package:rpboard/core/sync/version_policy.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/models/campaign.dart';
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
    int campaignCount = 0,
  }) {
    final characters = List.generate(
      characterCount,
      (i) => Character(id: 'c$i', name: 'Character $i'),
    );
    final campaigns = List.generate(
      campaignCount,
      (i) => Campaign(id: 'camp$i', createdAt: DateTime(2026), updatedAt: DateTime(2026)),
    );
    return ArchiveInfo(
      path: '/fake/archive.json',
      envelope: SnapshotEnvelope(
        formatVersion: 1,
        schemaVersion: schemaVersion,
        appVersion: '1.0.0+1',
        exportedAt: exportedAt,
        deviceLabel: deviceLabel,
        snapshot: AppSnapshot(characters: characters, campaigns: campaigns),
      ),
    );
  }

  /// Opens the dialog with `showDialog`, the way the screen opens it, and
  /// collects what it pops. That popped value is what the screen acts on, so
  /// a test asserting on it is asserting the dialog's real contract rather
  /// than a callback only tests pass.
  Future<List<bool?>> pump(
    WidgetTester tester, {
    required int localCharacterCount,
    int localCampaignCount = 0,
    required ArchiveInfo archive,
    SchemaVersionOutcome outcome = SchemaVersionOutcome.accepted,
    String refusalMessage = '',
  }) async {
    final popped = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => popped.add(await showDialog<bool>(
                context: context,
                builder: (_) => ImportConfirmationDialog(
                  localCharacterCount: localCharacterCount,
                  localCampaignCount: localCampaignCount,
                  archive: archive,
                  outcome: outcome,
                  refusalMessage: refusalMessage,
                ),
              )),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    return popped;
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

  testWidgets('cancelling refuses the import', (tester) async {
    final archive = archiveWith(
      characterCount: 1,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'x',
    );

    final popped = await pump(tester, localCharacterCount: 0, archive: archive);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(popped, [false]);
  });

  testWidgets('confirming confirms the import exactly once', (tester) async {
    final archive = archiveWith(
      characterCount: 1,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'x',
    );

    final popped = await pump(tester, localCharacterCount: 0, archive: archive);
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();

    expect(popped, [true]);
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

  testWidgets('shows the local and archive Campaign counts alongside the '
      'Character counts', (tester) async {
    final archive = archiveWith(
      characterCount: 3,
      campaignCount: 2,
      exportedAt: DateTime(2026, 1, 1),
      deviceLabel: 'DESKTOP-ONE',
    );

    await pump(
      tester,
      localCharacterCount: 5,
      localCampaignCount: 4,
      archive: archive,
    );

    expect(find.textContaining('5'), findsWidgets);
    expect(find.textContaining('3'), findsWidgets);
    expect(find.textContaining('4'), findsWidgets);
    expect(find.textContaining('2'), findsWidgets);
  });
}
