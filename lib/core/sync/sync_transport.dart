import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'snapshot_codec.dart';

/// One archive file a [SyncTransport] can see, with its envelope already
/// parsed so callers (the Trasferisci dati screen) never touch a file path
/// or raw JSON directly.
class ArchiveInfo {
  final String path;
  final SnapshotEnvelope envelope;

  const ArchiveInfo({required this.path, required this.envelope});
}

/// The only layer that touches platform I/O for data transfer (PRD
/// "Layering"): [SnapshotCodec] above handles format with no I/O, and the
/// `Database` seam below handles state. Exactly one adapter exists today —
/// [FolderSyncTransport] — so a future transport (a phone's share sheet, a
/// local-network transfer) can be added by implementing this same interface
/// without touching the codec or the database. See ADR-0007.
abstract interface class SyncTransport {
  /// The folder this transport reads and writes archives from, creating it
  /// if it doesn't exist yet. Shown in full on the Trasferisci dati screen,
  /// with the path spelled out, precisely because a conventional folder is
  /// otherwise a folder the user cannot find on their own.
  Future<String> exchangeFolderPath();

  /// Writes [contents] (a [SnapshotCodec]-encoded envelope) as a new archive
  /// file, never overwriting a previous export, and returns the path
  /// written to.
  Future<String> writeArchive(String contents);

  /// Every archive this transport can see, each with its envelope already
  /// parsed, in a deterministic order (most recently exported first). An
  /// archive file that fails to parse is skipped rather than surfaced —
  /// [readArchive] plus [SnapshotCodec.decode] is where a bad file is
  /// reported to the user, at the point they actually try to import it.
  Future<List<ArchiveInfo>> listArchives();

  /// Reads one archive's raw contents back, by the path an [ArchiveInfo]
  /// this same transport returned carries.
  Future<String> readArchive(String path);

  /// A label identifying this installation, used as an exported envelope's
  /// `deviceLabel`. Not domain data: never persisted in the database, and
  /// not available on the web target, where it degrades to a fixed label —
  /// the same `kIsWeb` guard `SqfliteDatabase` already applies before its
  /// own platform-specific initialisation.
  String deviceLabel();
}

/// The single adapter behind [SyncTransport]: a conventional folder inside
/// the app's own data directory, `transfer/` next to the database. No
/// file-picker dependency — the folder's path is written out in full on the
/// screen instead. See the data-transfer PRD and ADR-0007 for why.
class FolderSyncTransport implements SyncTransport {
  final SnapshotCodec codec;

  /// Where the app documents directory is resolved from. Defaults to the
  /// real `path_provider` lookup; a test overrides it with a temporary
  /// directory instead — plain constructor injection, mirroring
  /// `Migrations({this.ladder = productionLadder})`, rather than mocking
  /// `path_provider`'s platform channel (which would need a new dev
  /// dependency, `path_provider_platform_interface`, for no benefit over a
  /// parameter).
  final Future<String> Function() _documentsPath;

  FolderSyncTransport({
    this.codec = const SnapshotCodec(),
    @visibleForTesting Future<String> Function()? documentsPath,
  }) : _documentsPath = documentsPath ?? _defaultDocumentsPath;

  static Future<String> _defaultDocumentsPath() async =>
      (await getApplicationDocumentsDirectory()).path;

  Future<Directory> _folder() async {
    final docsPath = await _documentsPath();
    final dir = Directory(p.join(docsPath, 'rpboard', 'transfer'));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> exchangeFolderPath() async => (await _folder()).path;

  @override
  Future<String> writeArchive(String contents) async {
    final dir = await _folder();
    final base = 'rpboard-transfer-${_sanitizedTimestamp(DateTime.now())}';
    // Two exports within the same millisecond would otherwise collide on
    // name and silently overwrite one another — the one thing an export
    // must never do. A numeric suffix guarantees a fresh file every time.
    var file = File(p.join(dir.path, '$base.json'));
    var suffix = 1;
    while (await file.exists()) {
      file = File(p.join(dir.path, '$base-$suffix.json'));
      suffix++;
    }
    await file.writeAsString(contents);
    return file.path;
  }

  /// Filesystem-safe stand-in for a raw ISO-8601 string: Windows (the
  /// collaudo target) refuses `:` in a file name.
  static String _sanitizedTimestamp(DateTime t) =>
      t.toUtc().toIso8601String().replaceAll(':', '-');

  @override
  Future<List<ArchiveInfo>> listArchives() async {
    final dir = await _folder();
    final entries = await dir.list().toList();
    final infos = <ArchiveInfo>[];
    for (final entity in entries) {
      if (entity is! File || p.extension(entity.path) != '.json') continue;
      try {
        final contents = await entity.readAsString();
        infos.add(ArchiveInfo(path: entity.path, envelope: codec.decode(contents)));
      } catch (_) {
        continue; // Malformed/unreadable files are skipped, not surfaced here.
      }
    }
    infos.sort((a, b) => b.envelope.exportedAt.compareTo(a.envelope.exportedAt));
    return infos;
  }

  @override
  Future<String> readArchive(String path) => File(path).readAsString();

  @override
  String deviceLabel() {
    if (kIsWeb) return 'web';
    try {
      final name = Platform.localHostname.trim();
      return name.isEmpty ? 'sconosciuto' : name;
    } catch (_) {
      return 'sconosciuto';
    }
  }
}
