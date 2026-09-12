import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/core/database/migrations.dart';
import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/models/campaign.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/providers/data_transfer_provider.dart';
import 'package:rpboard/screens/data_transfer/data_transfer_screen.dart';

import '../../support/fake_sync_transport.dart';
import '../../support/in_memory_database.dart';

/// Widget-level coverage for [DataTransferScreen] against an
/// [InMemoryDatabase] and a [FakeSyncTransport] — no real SQLite, no real
/// filesystem. Prior art: `test/screens/pg/character_sheet_screen_test.dart`.
void main() {
  late InMemoryDatabase db;
  late FakeSyncTransport transport;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          syncTransportProvider.overrideWithValue(transport),
        ],
        child: const MaterialApp(home: DataTransferScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    db = InMemoryDatabase();
    transport = FakeSyncTransport();
  });

  testWidgets('shows the exchange folder path', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining(transport.folderPath), findsOneWidget);
  });

  testWidgets('import is unavailable with no archive present', (tester) async {
    await pumpScreen(tester);

    // No archive tile to tap, and no import affordance anywhere on screen —
    // the only interactive control is Export.
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Importa'), findsNothing);
    expect(find.textContaining('Nessun archivio'), findsOneWidget);
  });

  testWidgets('exporting adds an archive to the list', (tester) async {
    await db.insertCharacter(Character(id: 'a', name: 'Aragorn'));
    await pumpScreen(tester);

    await tester.tap(find.text('Esporta'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets(
      'an archive with a higher schemaVersion is visibly distinguishable in '
      'the list, before it is selected', (tester) async {
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'x', name: 'From the future'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion + 1,
      appVersion: '99.0.0',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'FUTURE-PC',
    ));

    await pumpScreen(tester);

    // The refusal is visible on the tile itself — a warning icon and the
    // update-this-installation message in place of the device label — with
    // no tap needed to discover it.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.textContaining('Aggiorna questa installazione'), findsOneWidget);
  });

  testWidgets(
      'a compatible archive shows the device label instead of a refusal '
      'warning', (tester) async {
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'x', name: 'From archive'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));

    await pumpScreen(tester);

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.textContaining('Da: OTHER-PC'), findsOneWidget);
  });

  testWidgets(
      'a file the codec could not decode is rendered as a refused entry '
      'with its reason, and offers no import affordance', (tester) async {
    transport.writeRawFile('damaged.json', 'not json at all {{{');
    await pumpScreen(tester);

    // The refused tile is visible with a readable reason...
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('damaged.json'), findsOneWidget);
    expect(find.text('Importa'), findsNothing);

    // ...and tapping it does nothing: no confirmation dialog opens.
    await tester.tap(find.byIcon(Icons.error_outline));
    await tester.pumpAndSettle();

    expect(find.text('Importa'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'a refused entry is listed alongside a usable archive without '
      'affecting the usable one', (tester) async {
    transport.writeRawFile('damaged.json', 'not json at all {{{');
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'x', name: 'From archive'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));

    await pumpScreen(tester);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('Da: OTHER-PC'), findsOneWidget);

    // The usable archive still opens its confirmation on tap.
    await tester.tap(find.textContaining('Da: OTHER-PC'));
    await tester.pumpAndSettle();

    expect(find.text('Importa'), findsOneWidget);
  });

  testWidgets('tapping an archive opens the import confirmation', (tester) async {
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'x', name: 'From archive'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));

    await pumpScreen(tester);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.text('Importa'), findsOneWidget);
    expect(find.textContaining('OTHER-PC'), findsWidgets);
  });

  testWidgets(
      'the confirmation names the local Campaign count, not just the '
      'Character count', (tester) async {
    await db.insertCampaign(Campaign(
      id: 'local-campaign',
      name: 'Local campaign',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));

    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'x', name: 'From archive'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));

    await pumpScreen(tester);
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    // The screen has to hand the count through; a dialog defaulting it to
    // zero would read 'Campagne locali: 0' with a campaign sitting locally.
    expect(find.text('Campagne locali: 1'), findsOneWidget);
    expect(find.text("Campagne nell'archivio: 0"), findsOneWidget);
  });

  testWidgets('cancelling the confirmation leaves local Characters unchanged',
      (tester) async {
    await db.insertCharacter(Character(id: 'local', name: 'Untouched'));
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'x', name: 'From archive'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));

    await pumpScreen(tester);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), ['local']);
  });

  testWidgets('the backup list renders its entries with their timestamps',
      (tester) async {
    await db.backupDatabase();

    await pumpScreen(tester);

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Ripristina'), findsOneWidget);
    expect(find.textContaining('Nessun backup'), findsNothing);
  });

  testWidgets('with no backup, the screen says so instead of listing one',
      (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('Nessun backup'), findsOneWidget);
  });

  testWidgets(
      'restoring a backup asks for confirmation before touching anything',
      (tester) async {
    await db.insertCharacter(Character(id: 'kept', name: 'Present at backup time'));
    await db.backupDatabase();
    await db.insertCharacter(Character(id: 'added-later', name: 'Not in the backup'));
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Ripristina'));
    await tester.pumpAndSettle();

    expect(find.text('Ripristina backup'), findsOneWidget,
        reason: 'restore must ask for its own confirmation before acting');

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), containsAll(['kept', 'added-later']),
        reason: 'cancelling the confirmation must not restore anything');
  });

  testWidgets('confirming a restore replaces local Characters with the '
      'backup\'s content', (tester) async {
    await db.insertCharacter(Character(id: 'kept', name: 'Present at backup time'));
    await db.backupDatabase();
    await db.insertCharacter(Character(id: 'added-later', name: 'Not in the backup'));
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Ripristina'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Ripristina'));
    await tester.pumpAndSettle();

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), ['kept']);
  });

  testWidgets('the open-folder control reaches the transport seam',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Apri cartella'));
    await tester.pumpAndSettle();

    expect(transport.openExchangeFolderCalled, isTrue);
  });
}
