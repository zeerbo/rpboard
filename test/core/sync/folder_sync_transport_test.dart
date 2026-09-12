import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/core/sync/sync_transport.dart';
import 'package:rpboard/models/app_snapshot.dart';
import 'package:rpboard/models/character.dart';

/// Realistic-failure tests for [FolderSyncTransport] against a real,
/// disposable temporary directory: a missing exchange folder on first use, a
/// non-archive file mixed in, write-then-read-back, and deterministic
/// listing order. Per the data-transfer PRD's testing decisions, this is
/// where the transport layer's realistic failure modes live — a missing
/// folder, a truncated file, a file that isn't an archive — rather than a
/// codec bug, which `snapshot_codec_test.dart` already covers with no I/O.
///
/// [FolderSyncTransport] takes an injectable `documentsPath` resolver
/// (mirroring `Migrations({this.ladder = productionLadder})`) precisely so
/// this file can point it at a temp directory without mocking
/// `path_provider`'s platform channel.
void main() {
  late Directory tempDir;
  late FolderSyncTransport transport;
  const codec = SnapshotCodec();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rpboard-transfer-test-');
    transport = FolderSyncTransport(documentsPath: () async => tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  String encodeArchive({required DateTime exportedAt, String deviceLabel = 'TEST-PC'}) =>
      codec.encode(
        snapshot: AppSnapshot(characters: [Character(id: 'a', name: 'Aria')]),
        schemaVersion: 4,
        appVersion: '1.0.0+1',
        exportedAt: exportedAt,
        deviceLabel: deviceLabel,
      );

  test('the exchange folder is created on first use and its path is under '
      'the app documents directory', () async {
    final folderExistedBefore = await Directory(p.join(tempDir.path, 'rpboard', 'transfer')).exists();
    expect(folderExistedBefore, isFalse,
        reason: 'a fresh install has no exchange folder yet');

    final path = await transport.exchangeFolderPath();

    expect(path, p.join(tempDir.path, 'rpboard', 'transfer'));
    expect(await Directory(path).exists(), isTrue);
  });

  test('listArchives on a fresh install with no exchange folder returns '
      'empty rather than throwing', () async {
    final archives = await transport.listArchives();

    expect(archives, isEmpty);
  });

  test('write then read back reproduces the exact archive contents', () async {
    final contents = encodeArchive(exportedAt: DateTime.utc(2026, 1, 1));

    final path = await transport.writeArchive(contents);
    final readBack = await transport.readArchive(path);

    expect(readBack, contents);
  });

  test('export never overwrites a previous archive: two writes produce two '
      'distinct files', () async {
    await transport.writeArchive(encodeArchive(exportedAt: DateTime.utc(2026, 1, 1)));
    await transport.writeArchive(encodeArchive(exportedAt: DateTime.utc(2026, 1, 2)));

    final folder = Directory(await transport.exchangeFolderPath());
    final files = await folder.list().toList();

    expect(files, hasLength(2));
  });

  test('archives are listed with their envelope metadata, most recently '
      'exported first', () async {
    await transport.writeArchive(
      encodeArchive(exportedAt: DateTime.utc(2026, 1, 1), deviceLabel: 'OLDEST'),
    );
    await transport.writeArchive(
      encodeArchive(exportedAt: DateTime.utc(2026, 6, 1), deviceLabel: 'NEWEST'),
    );
    await transport.writeArchive(
      encodeArchive(exportedAt: DateTime.utc(2026, 3, 1), deviceLabel: 'MIDDLE'),
    );

    final archives = await transport.listArchives();

    expect(archives.map((a) => a.envelope.deviceLabel), ['NEWEST', 'MIDDLE', 'OLDEST']);
    expect(archives.every((a) => a.envelope.schemaVersion == 4), isTrue);
  });

  test('a non-archive file in the folder is skipped, not surfaced as an '
      'archive', () async {
    final folder = Directory(await transport.exchangeFolderPath());
    await File(p.join(folder.path, 'not-an-archive.json')).writeAsString('not json');
    await File(p.join(folder.path, 'readme.txt')).writeAsString('hello');
    await transport.writeArchive(encodeArchive(exportedAt: DateTime.utc(2026, 1, 1)));

    final archives = await transport.listArchives();

    expect(archives, hasLength(1));
  });

  test('deviceLabel returns a non-empty string', () {
    expect(transport.deviceLabel(), isNotEmpty);
  });
}
