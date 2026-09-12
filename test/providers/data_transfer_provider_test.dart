import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/core/database/migrations.dart';
import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/core/sync/version_policy.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/providers/character_provider.dart';
import 'package:rpboard/providers/data_transfer_provider.dart';

import '../support/fake_sync_transport.dart';
import '../support/in_memory_database.dart';

/// Provider-level tests for [DataTransferNotifier], wiring
/// [databaseProvider] to an [InMemoryDatabase] and [syncTransportProvider]
/// to a [FakeSyncTransport] — no real SQLite, no real filesystem, no widget
/// pump. Mirrors `test/providers/character_provider_test.dart`.
void main() {
  late InMemoryDatabase db;
  late FakeSyncTransport transport;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      syncTransportProvider.overrideWithValue(transport),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = InMemoryDatabase();
    transport = FakeSyncTransport();
  });

  test('build reflects the exchange folder path, no archives, and the local '
      'Character count', () async {
    await db.insertCharacter(Character(id: 'a', name: 'Aragorn'));
    final container = makeContainer();

    final state = await container.read(dataTransferProvider.future);

    expect(state.exchangeFolderPath, transport.folderPath);
    expect(state.archives, isEmpty);
    expect(state.localCharacterCount, 1);
  });

  test('export works on a fresh install where the exchange folder does not '
      'exist yet', () async {
    final container = makeContainer();
    await container.read(dataTransferProvider.future);

    await container.read(dataTransferProvider.notifier).exportNow();

    final state = await container.read(dataTransferProvider.future);
    expect(state.archives, hasLength(1));
  });

  test('export writes an archive containing every Character', () async {
    await db.insertCharacter(Character(id: 'a', name: 'Aragorn'));
    await db.insertCharacter(Character(id: 'b', name: 'Boromir'));
    final container = makeContainer();
    await container.read(dataTransferProvider.future);

    await container.read(dataTransferProvider.notifier).exportNow();

    final state = await container.read(dataTransferProvider.future);
    final archive = state.archives.single;
    expect(archive.envelope.snapshot.characters.map((c) => c.id), ['a', 'b']);
    expect(archive.envelope.schemaVersion, const Migrations().latestVersion);
  });

  test('export never overwrites a previous archive', () async {
    final container = makeContainer();
    final notifier = container.read(dataTransferProvider.notifier);
    await container.read(dataTransferProvider.future);

    await notifier.exportNow();
    await notifier.exportNow();

    final state = await container.read(dataTransferProvider.future);
    expect(state.archives, hasLength(2));
  });

  test('importArchive replaces local Characters with the archive\'s, '
      'all-or-nothing', () async {
    await db.insertCharacter(Character(id: 'old', name: 'Will be replaced'));
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'new-1', name: 'From archive'));
    final exportedJson = const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    );
    await transport.writeArchive(exportedJson);

    final container = makeContainer();
    final state = await container.read(dataTransferProvider.future);
    final archive = state.archives.single;

    await container.read(dataTransferProvider.notifier).importArchive(archive);

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), ['new-1']);
    expect(await db.getCharacter('old'), isNull);
  });

  test('importArchive invalidates characterListProvider so PG Mode sees the '
      'new roster', () async {
    await db.insertCharacter(Character(id: 'old', name: 'Original'));
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'new-1', name: 'Replacement'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));

    final container = makeContainer();
    await container.read(characterListProvider.future);
    final state = await container.read(dataTransferProvider.future);

    await container.read(dataTransferProvider.notifier).importArchive(state.archives.single);

    final list = await container.read(characterListProvider.future);
    expect(list.map((c) => c.id), ['new-1']);
  });

  test('importArchive refuses an archive with a mismatched schemaVersion and '
      'leaves local data untouched', () async {
    await db.insertCharacter(Character(id: 'old', name: 'Untouched'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: const AppSnapshot(characters: []),
      schemaVersion: const Migrations().latestVersion + 1,
      appVersion: '2.0.0',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'FUTURE-PC',
    ));

    final container = makeContainer();
    final state = await container.read(dataTransferProvider.future);
    final archive = state.archives.single;

    await expectLater(
      container.read(dataTransferProvider.notifier).importArchive(archive),
      throwsA(isA<SnapshotVersionRefusedException>()),
    );

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), ['old']);
  });

  test('evaluateVersion accepts a matching schemaVersion', () async {
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: const AppSnapshot(characters: []),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'SAME-VERSION-PC',
    ));
    final container = makeContainer();
    final state = await container.read(dataTransferProvider.future);

    final outcome = container.read(dataTransferProvider.notifier).evaluateVersion(state.archives.single);

    expect(outcome, SchemaVersionOutcome.accepted);
  });

  test('build reflects the backups the database already holds', () async {
    await db.backupDatabase();
    final container = makeContainer();

    final state = await container.read(dataTransferProvider.future);

    expect(state.backups, hasLength(1));
  });

  test('importArchive backs up the database before replacing local '
      'Characters', () async {
    await db.insertCharacter(Character(id: 'old', name: 'Before the import'));
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'new-1', name: 'From archive'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));
    final container = makeContainer();
    final state = await container.read(dataTransferProvider.future);
    final archive = state.archives.single;

    expect(await db.listBackups(), isEmpty,
        reason: 'no backup exists yet, before the import runs');

    await container.read(dataTransferProvider.notifier).importArchive(archive);

    final backups = await db.listBackups();
    expect(backups, hasLength(1),
        reason: 'the import must be preceded by exactly one backup');

    // The backup must have captured the pre-import state, not the
    // post-import one.
    await db.restoreBackup(backups.single);
    expect((await db.getCharacters()).map((c) => c.id), ['old']);
  });

  test('importArchive aborts without touching local data when the backup '
      'cannot be written', () async {
    await db.insertCharacter(Character(id: 'untouched', name: 'Untouched'));
    db.backupFailure = Exception('simulated disk-full backup failure');
    final exporterDb = InMemoryDatabase();
    await exporterDb.insertCharacter(Character(id: 'new-1', name: 'From archive'));
    await transport.writeArchive(const SnapshotCodec().encode(
      snapshot: await exporterDb.exportSnapshot(),
      schemaVersion: const Migrations().latestVersion,
      appVersion: '1.0.0+1',
      exportedAt: DateTime.utc(2026, 1, 1),
      deviceLabel: 'OTHER-PC',
    ));
    final container = makeContainer();
    final state = await container.read(dataTransferProvider.future);
    final archive = state.archives.single;

    await expectLater(
      container.read(dataTransferProvider.notifier).importArchive(archive),
      throwsA(isA<Exception>()),
    );

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), ['untouched'],
        reason: 'a backup that cannot be written must abort the import '
            'rather than proceed unprotected');
  });

  test('restoreBackup replaces local Characters with the backup\'s content',
      () async {
    await db.insertCharacter(Character(id: 'kept', name: 'Present at backup time'));
    final container = makeContainer();
    await container.read(dataTransferProvider.future);
    final backup = await db.backupDatabase();

    await db.insertCharacter(Character(id: 'added-later', name: 'Not in the backup'));

    await container.read(dataTransferProvider.notifier).restoreBackup(backup);

    final characters = await db.getCharacters();
    expect(characters.map((c) => c.id), ['kept']);
  });

  test('restoreBackup invalidates characterListProvider so PG Mode sees the '
      'restored roster without an app restart', () async {
    await db.insertCharacter(Character(id: 'kept', name: 'Present at backup time'));
    final container = makeContainer();
    await container.read(characterListProvider.future);
    await container.read(dataTransferProvider.future);
    final backup = await db.backupDatabase();
    await db.insertCharacter(Character(id: 'added-later', name: 'Not in the backup'));

    await container.read(dataTransferProvider.notifier).restoreBackup(backup);

    final list = await container.read(characterListProvider.future);
    expect(list.map((c) => c.id), ['kept']);
  });
}
