import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_info.dart';
import '../core/database/db.dart';
import '../core/database/migrations.dart';
import '../core/sync/snapshot_codec.dart';
import '../core/sync/sync_transport.dart';
import '../core/sync/version_policy.dart';
import 'character_provider.dart';
import 'campaign_provider.dart';

/// Published seams for the data-transfer feature — analogous to
/// [databaseProvider]: a test overrides these with its own fakes, never a
/// static global.
final syncTransportProvider = Provider<SyncTransport>((ref) => FolderSyncTransport());
final snapshotCodecProvider = Provider<SnapshotCodec>((ref) => const SnapshotCodec());
final schemaVersionPolicyProvider =
    Provider<SchemaVersionPolicy>((ref) => const SchemaVersionPolicy());

/// This installation's own schema version — the single source of truth from
/// the `schema-version-single-source` prefactor, read here instead of a
/// second hand-written literal.
int localSchemaVersion() => const Migrations().latestVersion;

/// Thrown by [DataTransferNotifier.importArchive] when [SchemaVersionPolicy]
/// refuses the archive. Carries the user-facing message the confirmation
/// flow shows instead of proceeding.
class SnapshotVersionRefusedException implements Exception {
  final String message;
  const SnapshotVersionRefusedException(this.message);

  @override
  String toString() => message;
}

/// Everything the Trasferisci dati screen needs to render itself: the
/// exchange folder's path, the archives found there, the files in that
/// folder [SnapshotCodec] could not decode (each carrying its own reason,
/// per ticket 05), the local Character/Campaign counts the confirmation
/// dialog compares against an archive's, and the backups available to
/// restore from.
class DataTransferViewState {
  final String exchangeFolderPath;
  final List<ArchiveInfo> archives;
  final List<RefusedArchiveInfo> refusedArchives;
  final int localCharacterCount;
  final int localCampaignCount;
  final List<DatabaseBackupInfo> backups;

  const DataTransferViewState({
    required this.exchangeFolderPath,
    required this.archives,
    required this.refusedArchives,
    required this.localCharacterCount,
    required this.localCampaignCount,
    required this.backups,
  });
}

/// Orchestrates the three layers the PRD names — [SyncTransport] for I/O,
/// [SnapshotCodec] for format, the `Database` seam for state — into the two
/// user-facing actions the screen offers: export and import. Neither layer
/// talks to the others directly; this notifier is the one place that wires
/// them together, the same role a screen's list notifier plays for CRUD.
class DataTransferNotifier extends AsyncNotifier<DataTransferViewState> {
  @override
  Future<DataTransferViewState> build() async {
    final transport = ref.read(syncTransportProvider);
    final db = ref.read(databaseProvider);
    final folderPath = await transport.exchangeFolderPath();
    final listing = await transport.listArchives();
    final characters = await db.getCharacters();
    final campaigns = await db.getCampaigns();
    final backups = await db.listBackups();
    return DataTransferViewState(
      exchangeFolderPath: folderPath,
      archives: listing.archives,
      refusedArchives: listing.refused,
      localCharacterCount: characters.length,
      localCampaignCount: campaigns.length,
      backups: backups,
    );
  }

  /// Exports the complete current state to a new archive file, then
  /// refreshes the screen's view of the exchange folder.
  Future<void> exportNow() async {
    final db = ref.read(databaseProvider);
    final transport = ref.read(syncTransportProvider);
    final codec = ref.read(snapshotCodecProvider);

    final snapshot = await db.exportSnapshot();
    final envelopeJson = codec.encode(
      snapshot: snapshot,
      schemaVersion: localSchemaVersion(),
      appVersion: kAppVersion,
      exportedAt: DateTime.now(),
      deviceLabel: transport.deviceLabel(),
    );
    await transport.writeArchive(envelopeJson);
    ref.invalidateSelf();
  }

  /// The version-policy outcome for [archive] against this installation —
  /// what the confirmation flow checks before offering to import at all.
  SchemaVersionOutcome evaluateVersion(ArchiveInfo archive) {
    final policy = ref.read(schemaVersionPolicyProvider);
    return policy.evaluate(
      localSchemaVersion: localSchemaVersion(),
      archiveSchemaVersion: archive.envelope.schemaVersion,
    );
  }

  /// A user-facing explanation for why [archive] was refused. Only
  /// meaningful when [evaluateVersion] didn't return
  /// [SchemaVersionOutcome.accepted].
  String refusalMessageFor(ArchiveInfo archive) {
    final policy = ref.read(schemaVersionPolicyProvider);
    return policy.refusalMessage(
      localSchemaVersion: localSchemaVersion(),
      archiveSchemaVersion: archive.envelope.schemaVersion,
    );
  }

  /// Replaces the local Characters and Campaign material with [archive]'s
  /// content, atomically, through the `Database` seam. Throws
  /// [SnapshotVersionRefusedException] without touching the database at all
  /// when the version policy refuses the archive.
  ///
  /// Before any row is touched, the current database is backed up
  /// (PRD, ticket 04: "the app takes a backup of the destination's database
  /// before it touches anything"). If the backup itself cannot be written,
  /// the exception propagates and the import never runs — a failed backup
  /// aborts the import rather than proceeding unprotected.
  Future<void> importArchive(ArchiveInfo archive) async {
    final outcome = evaluateVersion(archive);
    if (outcome != SchemaVersionOutcome.accepted) {
      throw SnapshotVersionRefusedException(refusalMessageFor(archive));
    }

    final db = ref.read(databaseProvider);
    await db.backupDatabase();
    await db.importSnapshot(archive.envelope.snapshot);
    _refreshEverything();
  }

  /// Restores [backup] over the current database, then refreshes both this
  /// screen's state and every aggregate's list so the restored state is
  /// visible immediately — no app restart needed. A restore puts back the
  /// whole database file, so Campaign material is refreshed alongside the
  /// Character roster, exactly as an import refreshes it.
  ///
  /// Restore is only ever called from an explicit user action with its own
  /// confirmation; it is never triggered automatically, including on an
  /// import failure.
  Future<void> restoreBackup(DatabaseBackupInfo backup) async {
    final db = ref.read(databaseProvider);
    await db.restoreBackup(backup);
    _refreshEverything();
  }

  /// Both write paths here — an import and a restore — replace every
  /// aggregate the user owns at once, so both refresh this screen and every
  /// list reading from the database. Kept in one place because a new
  /// aggregate's list provider must be added for both or neither.
  void _refreshEverything() {
    ref.invalidateSelf();
    ref.invalidate(characterListProvider);
    ref.invalidate(campaignListProvider);
    ref.invalidate(chapterListProvider);
    ref.invalidate(screenListProvider);
    ref.invalidate(componentListProvider);
  }

  /// Opens the exchange folder in the platform's file manager. Platform
  /// I/O, so this is a thin passthrough to the transport seam rather than
  /// something the screen reaches for directly.
  Future<void> openExchangeFolder() =>
      ref.read(syncTransportProvider).openExchangeFolder();
}

final dataTransferProvider =
    AsyncNotifierProvider<DataTransferNotifier, DataTransferViewState>(
  DataTransferNotifier.new,
);
