import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/core/database/migrations.dart';
import 'package:rpboard/core/sync/snapshot_codec.dart';
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
}
