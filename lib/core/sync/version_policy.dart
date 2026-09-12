/// Whether an archive's `schemaVersion` may be imported into this
/// installation.
enum SchemaVersionOutcome {
  /// The archive may be imported. This covers an equal `schemaVersion` and,
  /// deliberately, a lower one too: fields an older archive doesn't carry
  /// take the defaults the models already apply on a missing key —
  /// `Character.fromMap` alone has 102 `??` fallbacks — so tolerating a
  /// lower schema is relying on existing behaviour, not adding new leniency.
  accepted,

  /// The archive was produced by a newer schema than this installation
  /// understands. Refused: importing it would mean silently discarding
  /// fields the archive carries and this installation cannot represent —
  /// data loss dressed as a feature.
  refusedNewer,
}

/// Compares an archive's `schemaVersion` against this installation's own,
/// with no database opened and no I/O — the "version policy" the PRD assigns
/// to the codec layer.
///
/// The policy is asymmetric, per the data-transfer PRD's "Version
/// compatibility is asymmetric: accept older, refuse newer": an archive from
/// an equal or lower schema imports; one from a higher schema is refused. An
/// earlier ticket (02) shipped a stricter interim policy — equal only — so
/// that this relaxation would be a visible, deliberate change to
/// `version_policy_test.dart` rather than something pre-empted.
class SchemaVersionPolicy {
  const SchemaVersionPolicy();

  SchemaVersionOutcome evaluate({
    required int localSchemaVersion,
    required int archiveSchemaVersion,
  }) {
    return archiveSchemaVersion > localSchemaVersion
        ? SchemaVersionOutcome.refusedNewer
        : SchemaVersionOutcome.accepted;
  }

  /// A user-facing explanation for a refusal, telling the user to update
  /// this installation. Only meaningful when [evaluate] returned
  /// [SchemaVersionOutcome.refusedNewer] — the only outcome this policy ever
  /// refuses.
  String refusalMessage({
    required int localSchemaVersion,
    required int archiveSchemaVersion,
  }) {
    return 'Questo archivio proviene da una versione più recente di '
        'RPBoard (schema $archiveSchemaVersion; questa installazione '
        'legge fino allo schema $localSchemaVersion). Aggiorna questa '
        'installazione prima di importarlo.';
  }
}
