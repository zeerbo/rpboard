/// Whether an archive's `schemaVersion` may be imported into this
/// installation.
enum SchemaVersionOutcome {
  /// The archive may be imported.
  accepted,

  /// The archive was produced by a newer schema than this installation
  /// understands. Refused: importing it would mean silently discarding
  /// fields the archive carries and this installation cannot represent.
  refusedNewer,

  /// The archive's schema is older than this installation's. Ticket 02
  /// refuses this too — see [SchemaVersionPolicy] doc — a later ticket
  /// relaxes it to accept older archives.
  refusedOlder,
}

/// Compares an archive's `schemaVersion` against this installation's own,
/// with no database opened and no I/O — the "version policy" the PRD assigns
/// to the codec layer.
///
/// **This ticket's policy is strict**: only an exact match is accepted. The
/// data-transfer PRD's eventual policy is asymmetric — accept an older
/// archive (the models' own `?? ` fallbacks already tolerate missing
/// fields), refuse a newer one — but that relaxation is a later ticket's
/// decision, not pre-implemented here.
class SchemaVersionPolicy {
  const SchemaVersionPolicy();

  SchemaVersionOutcome evaluate({
    required int localSchemaVersion,
    required int archiveSchemaVersion,
  }) {
    if (archiveSchemaVersion == localSchemaVersion) {
      return SchemaVersionOutcome.accepted;
    }
    return archiveSchemaVersion > localSchemaVersion
        ? SchemaVersionOutcome.refusedNewer
        : SchemaVersionOutcome.refusedOlder;
  }

  /// A user-facing explanation for a refusal. Only meaningful when
  /// [evaluate] did not return [SchemaVersionOutcome.accepted].
  String refusalMessage({
    required int localSchemaVersion,
    required int archiveSchemaVersion,
  }) {
    if (archiveSchemaVersion > localSchemaVersion) {
      return 'Questo archivio proviene da una versione più recente di '
          'RPBoard (schema $archiveSchemaVersion). Aggiorna questa '
          'installazione prima di importarlo.';
    }
    return 'Questo archivio non è compatibile con questa installazione '
        '(schema $archiveSchemaVersion, richiesto $localSchemaVersion).';
  }
}
