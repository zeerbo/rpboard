import 'character.dart';
import 'campaign.dart';
import 'chapter.dart';
import 'session_screen.dart';
import 'component.dart';

/// The complete application state at one instant, for the data-transfer
/// feature (`Trasferisci dati`): every root aggregate the user owns, held as
/// the same typed domain models the rest of the app uses — never a raw JSON
/// map. This extends ADR-0001's rule for `ComponentData` ("persisted as JSON
/// but manipulated as a typed Dart object") to the whole transfer path. See
/// ADR-0007.
///
/// `AppSnapshot` is pure data with no I/O: it does not know how it is
/// serialized (that's `SnapshotCodec`, above it) or how it reaches disk
/// (`SyncTransport`, above that again) or how it is read from or written to
/// the database (the `Database` seam's `exportSnapshot`/`importSnapshot`,
/// below it).
///
/// **Standing obligation:** touching the data model — adding a table, adding
/// a field a user's data depends on — means extending this class and its
/// round-trip test (`snapshot_codec_test.dart`), or the new data is silently
/// dropped on export. This is recorded three times on purpose: here, in
/// `CONTEXT.md`, and in `CLAUDE.md`.
///
/// **Scope:** every Character, and every Campaign with its owned Chapters,
/// SessionScreens and SessionComponents — the four Campaign-material lists
/// are flat (each entity already carries its own owning-parent id, exactly
/// as the database rows do), not a nested tree; nesting would duplicate the
/// parent-id relationship the models already express. An archive produced
/// before Campaign material was added to the format (this ticket's
/// predecessor) carries none of these four lists; decoding one defaults them
/// to empty, so it still imports cleanly.
///
/// **Known effect, not a defect:** exporting reaches Chapters only by
/// descending from a Campaign (Campaign → Chapter → SessionScreen →
/// SessionComponent), so a row orphaned by the foreign-key enforcement defect
/// (see ADR-0006) is never exported, and the first import after that deletes
/// it along with everything else the destination held. This is expected and
/// recorded here and in ADR-0007's Consequences; the ticket that adds
/// Campaign material to the snapshot does not try to preserve orphans.
class AppSnapshot {
  final List<Character> characters;
  final List<Campaign> campaigns;
  final List<Chapter> chapters;
  final List<SessionScreen> screens;
  final List<SessionComponent> components;

  const AppSnapshot({
    required this.characters,
    this.campaigns = const [],
    this.chapters = const [],
    this.screens = const [],
    this.components = const [],
  });
}
