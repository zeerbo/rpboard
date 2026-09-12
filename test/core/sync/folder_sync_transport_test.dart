import 'dart:convert';
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
    final listing = await transport.listArchives();

    expect(listing.archives, isEmpty);
    expect(listing.refused, isEmpty);
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

    final listing = await transport.listArchives();

    expect(listing.archives.map((a) => a.envelope.deviceLabel), ['NEWEST', 'MIDDLE', 'OLDEST']);
    expect(listing.archives.every((a) => a.envelope.schemaVersion == 4), isTrue);
  });

  // A file this codec cannot decode must not become an ArchiveInfo — the
  // pre-existing test below still asserts exactly that — but ticket 05
  // additionally requires it not be dropped silently: it must come back as
  // its own RefusedArchiveInfo, carrying a readable reason, so the screen
  // can explain the refusal before the user selects anything.
  test('a non-archive file in the folder is not surfaced as an archive, but '
      'is reported as a refused entry with a readable reason', () async {
    final folder = Directory(await transport.exchangeFolderPath());
    await File(p.join(folder.path, 'not-an-archive.json')).writeAsString('not json');
    await File(p.join(folder.path, 'readme.txt')).writeAsString('hello');
    await transport.writeArchive(encodeArchive(exportedAt: DateTime.utc(2026, 1, 1)));

    final listing = await transport.listArchives();

    // The good archive is the only usable one; the malformed .json file is
    // refused with a reason, and the non-.json file is not even a
    // candidate archive (matching the app's own '.json' export convention)
    // so it appears in neither list.
    expect(listing.archives, hasLength(1));
    expect(listing.refused, hasLength(1));
    expect(listing.refused.single.path, endsWith('not-an-archive.json'));
    expect(listing.refused.single.reason, isNotEmpty);
  });

  test('a file with a formatVersion this codec does not speak is reported as '
      'a refused entry with its own message, not surfaced as an archive',
      () async {
    final folder = Directory(await transport.exchangeFolderPath());
    await File(p.join(folder.path, 'future-format.json')).writeAsString(
      '{"formatVersion": 99, "schemaVersion": 4, "appVersion": "9.0.0", '
      '"exportedAt": "2026-01-01T00:00:00.000Z", "deviceLabel": "x", '
      '"payload": {"characters": []}}',
    );
    await transport.writeArchive(encodeArchive(exportedAt: DateTime.utc(2026, 1, 1)));

    final listing = await transport.listArchives();

    expect(listing.archives, hasLength(1));
    expect(listing.refused, hasLength(1));
    expect(listing.refused.single.reason, contains('formatVersion'));
  });

  test('an archive with a higher schemaVersion than this codec\'s own is '
      'still listed — it is the version *policy*, evaluated above this '
      'layer, that refuses it, not the transport or the codec', () async {
    await transport.writeArchive(encodeArchive(exportedAt: DateTime.utc(2026, 1, 1)));
    await transport.writeArchive(codec.encode(
      snapshot: const AppSnapshot(characters: []),
      schemaVersion: 999,
      appVersion: '99.0.0',
      exportedAt: DateTime.utc(2026, 2, 1),
      deviceLabel: 'FUTURE-PC',
    ));

    final listing = await transport.listArchives();

    expect(listing.archives, hasLength(2));
    expect(listing.archives.map((a) => a.envelope.schemaVersion), [999, 4]);
    expect(listing.refused, isEmpty);
  });

  test('deviceLabel returns a non-empty string', () {
    expect(transport.deviceLabel(), isNotEmpty);
  });

  group('format-level refusals (ticket 05)', () {
    Future<void> writeRaw(Directory folder, String name, String contents) =>
        File(p.join(folder.path, name)).writeAsString(contents);

    test('a file that is not JSON at all is refused with a readable error, '
        'never surfaced as an archive', () async {
      final folder = Directory(await transport.exchangeFolderPath());
      await writeRaw(folder, 'garbage.json', 'this is definitely not json {{{');

      final listing = await transport.listArchives();

      expect(listing.archives, isEmpty);
      expect(listing.refused, hasLength(1));
      expect(listing.refused.single.reason, isNotEmpty);
    });

    test('a file that is valid JSON but not an RPBoard archive is refused, '
        'never surfaced as an archive', () async {
      final folder = Directory(await transport.exchangeFolderPath());
      await writeRaw(folder, 'not-an-envelope.json', '["just", "an", "array"]');

      final listing = await transport.listArchives();

      expect(listing.archives, isEmpty);
      expect(listing.refused, hasLength(1));
      expect(listing.refused.single.reason, isNotEmpty);
    });

    test('an archive with a missing version field is refused, never '
        'surfaced as an archive', () async {
      final folder = Directory(await transport.exchangeFolderPath());
      await writeRaw(folder, 'missing-version.json', jsonEncode({
        'schemaVersion': 4,
        'appVersion': '1.0.0',
        'exportedAt': '2026-01-01T00:00:00.000Z',
        'deviceLabel': 'x',
        'payload': {'characters': []},
      }));

      final listing = await transport.listArchives();

      expect(listing.archives, isEmpty);
      expect(listing.refused, hasLength(1));
      expect(listing.refused.single.reason, contains('formatVersion'));
    });

    test('an archive with a non-numeric version field is refused, never '
        'surfaced as an archive', () async {
      final folder = Directory(await transport.exchangeFolderPath());
      await writeRaw(folder, 'non-numeric-version.json', jsonEncode({
        'formatVersion': 'uno',
        'schemaVersion': 4,
        'appVersion': '1.0.0',
        'exportedAt': '2026-01-01T00:00:00.000Z',
        'deviceLabel': 'x',
        'payload': {'characters': []},
      }));

      final listing = await transport.listArchives();

      expect(listing.archives, isEmpty);
      expect(listing.refused, hasLength(1));
      expect(listing.refused.single.reason, contains('formatVersion'));
    });

    test('a truncated archive is refused, never surfaced as an archive',
        () async {
      final folder = Directory(await transport.exchangeFolderPath());
      final wholeArchive = encodeArchive(exportedAt: DateTime.utc(2026, 1, 1));
      await writeRaw(
        folder,
        'truncated.json',
        wholeArchive.substring(0, wholeArchive.length ~/ 2),
      );

      final listing = await transport.listArchives();

      expect(listing.archives, isEmpty);
      expect(listing.refused, hasLength(1));
      expect(listing.refused.single.reason, isNotEmpty);
    });

    test('an archive with a mismatched formatVersion is refused with its '
        'own message, never surfaced as an archive', () async {
      final folder = Directory(await transport.exchangeFolderPath());
      await writeRaw(folder, 'future-format-2.json', jsonEncode({
        'formatVersion': SnapshotCodec.formatVersion + 1,
        'schemaVersion': 4,
        'appVersion': '9.0.0',
        'exportedAt': '2026-01-01T00:00:00.000Z',
        'deviceLabel': 'x',
        'payload': {'characters': []},
      }));

      final listing = await transport.listArchives();

      expect(listing.archives, isEmpty);
      expect(listing.refused, hasLength(1));
      expect(listing.refused.single.reason, contains('formatVersion'));
    });

    test('a folder holding both a good archive and a damaged file reports '
        'the good one as usable and the damaged one as refused', () async {
      final folder = Directory(await transport.exchangeFolderPath());
      await writeRaw(folder, 'damaged.json', 'not json at all {{{');
      final goodPath = await transport.writeArchive(
        encodeArchive(exportedAt: DateTime.utc(2026, 1, 1), deviceLabel: 'GOOD-PC'),
      );

      final listing = await transport.listArchives();

      expect(listing.archives, hasLength(1));
      expect(listing.archives.single.path, goodPath);
      expect(listing.archives.single.envelope.deviceLabel, 'GOOD-PC');
      expect(listing.refused, hasLength(1));
      expect(listing.refused.single.path, endsWith('damaged.json'));
    });
  });
}
