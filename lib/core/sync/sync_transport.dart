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

/// One file a [SyncTransport] found in the exchange folder that
/// [SnapshotCodec] could not decode: not JSON, JSON but not an RPBoard
/// archive, a missing/non-numeric version field, a `formatVersion` this
/// codec does not speak, or a truncated payload. Deliberately **not** an
/// [ArchiveInfo] — the two are kept separate in the type system so a file
/// this transport cannot read can never be mistaken for one it can (see
/// ticket 05 in `.scratch/data-transfer/`). Carries [reason] verbatim from
/// [SnapshotFormatException.message] so the Trasferisci dati screen can show
/// the codec's own explanation without re-deriving it.
class RefusedArchiveInfo {
  final String path;
  final String reason;

  const RefusedArchiveInfo({required this.path, required this.reason});
}

/// Everything [SyncTransport.listArchives] finds in the exchange folder,
/// split into the archives usable for import and the files refused because
/// [SnapshotCodec] could not decode them. Kept as two separate lists rather
/// than one mixed list precisely so a refused file can never be handed
/// somewhere an [ArchiveInfo] is expected.
class ArchiveListing {
  final List<ArchiveInfo> archives;
  final List<RefusedArchiveInfo> refused;

  const ArchiveListing({required this.archives, required this.refused});
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

  /// Every `.json` file this transport finds in the exchange folder,
  /// classified into usable archives (each with its envelope already
  /// parsed, in a deterministic order — most recently exported first) and
  /// files [SnapshotCodec] refused to decode. A refused file is never
  /// silently dropped: it is surfaced as its own [RefusedArchiveInfo],
  /// carrying the codec's own message, so the Trasferisci dati screen can
  /// show the user why it cannot be used before they select it (ticket 05).
  Future<ArchiveListing> listArchives();

  /// Reads one archive's raw contents back, by the path an [ArchiveInfo]
  /// this same transport returned carries.
  Future<String> readArchive(String path);

  /// A label identifying this installation, used as an exported envelope's
  /// `deviceLabel`. Not domain data: never persisted in the database, and
  /// not available on the web target, where it degrades to a fixed label —
  /// the same `kIsWeb` guard `SqfliteDatabase` already applies before its
  /// own platform-specific initialisation.
  String deviceLabel();

  /// Opens the exchange folder in the platform's file manager (Explorer,
  /// Finder, the desktop environment's file manager), so moving the
  /// exported file to another machine is a click plus a drag rather than
  /// typing the path shown on the screen. Platform I/O, so — like every
  /// other piece of platform I/O this feature needs — it lives behind this
  /// seam rather than being called inline from the screen.
  Future<void> openExchangeFolder();
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
  Future<ArchiveListing> listArchives() async {
    final dir = await _folder();
    final entries = await dir.list().toList();
    final archives = <ArchiveInfo>[];
    final refused = <RefusedArchiveInfo>[];
    for (final entity in entries) {
      if (entity is! File || p.extension(entity.path) != '.json') continue;
      try {
        final contents = await entity.readAsString();
        archives.add(ArchiveInfo(path: entity.path, envelope: codec.decode(contents)));
      } on SnapshotFormatException catch (e) {
        // Not JSON, JSON but not an archive, an unreadable version field, a
        // formatVersion mismatch, or a truncated payload: SnapshotCodec.decode
        // already distinguishes each of these with its own message. This is
        // the one place that message reaches the user (ticket 05) — it must
        // never become an ArchiveInfo, so a refused file can't be mistaken
        // for one the user can import.
        refused.add(RefusedArchiveInfo(path: entity.path, reason: e.message));
      } catch (e) {
        // Anything else (e.g. the file could not even be read) is refused
        // the same way, with whatever the platform reports as the reason.
        refused.add(RefusedArchiveInfo(path: entity.path, reason: e.toString()));
      }
    }
    archives.sort((a, b) => b.envelope.exportedAt.compareTo(a.envelope.exportedAt));
    refused.sort((a, b) => a.path.compareTo(b.path));
    return ArchiveListing(archives: archives, refused: refused);
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

  /// No file-picker dependency was needed for the folder itself (see the
  /// PRD and ADR-0007's "file-picker dependency" rejection), and none is
  /// needed here either: every desktop platform this app targets already
  /// ships a command that hands a folder to its file manager, reachable
  /// through `dart:io`'s [Process] with no new pub dependency. There is no
  /// equivalent concept on the web target, where this is a no-op.
  @override
  Future<void> openExchangeFolder() async {
    if (kIsWeb) return;
    final path = await exchangeFolderPath();
    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
    // `explorer.exe` in particular is known to report a non-zero exit code
    // even when it opens the folder successfully, so the exit code is
    // deliberately not inspected here.
  }
}
