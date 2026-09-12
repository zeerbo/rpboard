import 'package:rpboard/core/sync/snapshot_codec.dart';
import 'package:rpboard/core/sync/sync_transport.dart';

/// A behavioral [SyncTransport] fake for provider- and widget-level tests —
/// the transport-layer counterpart to `InMemoryDatabase`. Test-only: lives
/// under `test/`, never `lib/`, so no shipped code can depend on it.
///
/// Backed by an in-memory map of path -> raw contents instead of a real
/// filesystem, so tests that only care about the orchestration above the
/// transport (`DataTransferNotifier`, the confirmation dialog) don't pay
/// for real file I/O. The transport's own realistic-failure behaviour
/// (a missing folder, a malformed file, write-then-read-back) is covered
/// against a real temporary directory in
/// `test/core/sync/folder_sync_transport_test.dart` instead.
class FakeSyncTransport implements SyncTransport {
  final SnapshotCodec codec;
  String folderPath;
  String deviceLabelValue;
  final Map<String, String> files = {};
  int _counter = 0;

  FakeSyncTransport({
    this.codec = const SnapshotCodec(),
    this.folderPath = '/fake/rpboard/transfer',
    this.deviceLabelValue = 'FAKE-DEVICE',
  });

  @override
  Future<String> exchangeFolderPath() async => folderPath;

  @override
  Future<String> writeArchive(String contents) async {
    final path = '$folderPath/rpboard-transfer-fake-${_counter++}.json';
    files[path] = contents;
    return path;
  }

  @override
  Future<List<ArchiveInfo>> listArchives() async {
    final infos = <ArchiveInfo>[];
    for (final entry in files.entries) {
      try {
        infos.add(ArchiveInfo(path: entry.key, envelope: codec.decode(entry.value)));
      } catch (_) {
        continue;
      }
    }
    infos.sort((a, b) => b.envelope.exportedAt.compareTo(a.envelope.exportedAt));
    return infos;
  }

  @override
  Future<String> readArchive(String path) async {
    final contents = files[path];
    if (contents == null) {
      throw StateError('no archive at $path');
    }
    return contents;
  }

  @override
  String deviceLabel() => deviceLabelValue;

  /// Tracks whether [openExchangeFolder] was called, so a widget test can
  /// assert the screen's control reaches the transport seam without any
  /// real platform I/O.
  bool openExchangeFolderCalled = false;

  @override
  Future<void> openExchangeFolder() async {
    openExchangeFolderCalled = true;
  }
}
