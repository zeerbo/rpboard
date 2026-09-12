import 'character.dart';

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
/// **Current scope:** Characters only. Campaign material (Campaigns with
/// their Chapters, SessionScreens and SessionComponents) is added by a later
/// ticket as another field on this class and another key in the codec's
/// envelope payload — additive, not a reshape of the format.
class AppSnapshot {
  final List<Character> characters;

  const AppSnapshot({required this.characters});
}
