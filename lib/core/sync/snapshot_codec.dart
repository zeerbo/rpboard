import 'dart:convert';

import '../../models/app_snapshot.dart';
import '../../models/character.dart';

/// Thrown when a string handed to [SnapshotCodec.decode] is not a readable
/// RPBoard archive: not JSON at all, JSON but not an envelope, an envelope
/// missing a required field or carrying one of the wrong type, or a payload
/// entry that doesn't parse. Every case is refused with no partial
/// application — [SnapshotCodec.decode] either returns a complete
/// [SnapshotEnvelope] or throws, never something half-built.
class SnapshotFormatException implements Exception {
  final String message;
  const SnapshotFormatException(this.message);

  @override
  String toString() => 'SnapshotFormatException: $message';
}

/// The versioned envelope an archive file carries, wrapping the serialized
/// [AppSnapshot] with metadata the confirmation screen and the version
/// policy both need without opening the database. See the data-transfer
/// PRD's "The exchange format is logical JSON with a versioned envelope".
class SnapshotEnvelope {
  /// Version of the exchange format itself — the JSON shape [SnapshotCodec]
  /// reads and writes. Independent of [schemaVersion]: the two change for
  /// different reasons.
  final int formatVersion;

  /// The database schema version the payload was produced from.
  final int schemaVersion;

  /// The app version string that produced this archive. Informational only;
  /// never used for a compatibility decision.
  final String appVersion;

  /// When the archive was exported.
  final DateTime exportedAt;

  /// Which installation produced the archive, taken from the platform's
  /// host name at export time. A label, not domain data: never persisted in
  /// the database.
  final String deviceLabel;

  /// The application state the archive carries.
  final AppSnapshot snapshot;

  const SnapshotEnvelope({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.deviceLabel,
    required this.snapshot,
  });
}

/// `AppSnapshot` <-> JSON, envelope, and (as a pure, no-database-open
/// function elsewhere in this file's sibling module) the version policy.
/// This is the middle layer of the PRD's "Layering" table: it touches no
/// platform I/O — that's `SyncTransport` above it — and it never reaches
/// into the database — that's the `Database` seam below it.
class SnapshotCodec {
  /// The exchange format's own version. Bumped when the JSON shape changes,
  /// independent of the database [schemaVersion] carried inside each
  /// envelope.
  static const int formatVersion = 1;

  const SnapshotCodec();

  /// Serializes [snapshot] into a complete envelope, ready to hand to a
  /// [SyncTransport] to write out.
  String encode({
    required AppSnapshot snapshot,
    required int schemaVersion,
    required String appVersion,
    required DateTime exportedAt,
    required String deviceLabel,
  }) {
    final envelope = <String, dynamic>{
      'formatVersion': formatVersion,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'deviceLabel': deviceLabel,
      'payload': _encodePayload(snapshot),
    };
    return jsonEncode(envelope);
  }

  Map<String, dynamic> _encodePayload(AppSnapshot snapshot) => {
        'characters': snapshot.characters.map((c) => c.toMap()).toList(),
      };

  /// Parses [source] into a [SnapshotEnvelope], or throws
  /// [SnapshotFormatException] with a distinguishable message. Never returns
  /// a partially-built envelope.
  SnapshotEnvelope decode(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const SnapshotFormatException(
          'il file non è JSON valido');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const SnapshotFormatException(
          'il file non è un archivio RPBoard: atteso un oggetto JSON');
    }

    final formatVersionValue = decoded['formatVersion'];
    if (formatVersionValue is! int) {
      throw const SnapshotFormatException(
          'formatVersion mancante o non numerico');
    }

    final schemaVersionValue = decoded['schemaVersion'];
    if (schemaVersionValue is! int) {
      throw const SnapshotFormatException(
          'schemaVersion mancante o non numerico');
    }

    final appVersionValue = decoded['appVersion'];
    if (appVersionValue is! String) {
      throw const SnapshotFormatException(
          'appVersion mancante o non testuale');
    }

    final exportedAtRaw = decoded['exportedAt'];
    if (exportedAtRaw is! String) {
      throw const SnapshotFormatException(
          'exportedAt mancante o non testuale');
    }
    final DateTime exportedAt;
    try {
      exportedAt = DateTime.parse(exportedAtRaw);
    } on FormatException {
      throw const SnapshotFormatException(
          'exportedAt non è una data ISO-8601 valida');
    }

    final deviceLabelValue = decoded['deviceLabel'];
    if (deviceLabelValue is! String) {
      throw const SnapshotFormatException(
          'deviceLabel mancante o non testuale');
    }

    final payloadValue = decoded['payload'];
    if (payloadValue is! Map<String, dynamic>) {
      throw const SnapshotFormatException('payload mancante o malformato');
    }

    return SnapshotEnvelope(
      formatVersion: formatVersionValue,
      schemaVersion: schemaVersionValue,
      appVersion: appVersionValue,
      exportedAt: exportedAt,
      deviceLabel: deviceLabelValue,
      snapshot: _decodePayload(payloadValue),
    );
  }

  AppSnapshot _decodePayload(Map<String, dynamic> payload) {
    final rawCharacters = payload['characters'];
    if (rawCharacters == null) return const AppSnapshot(characters: []);
    if (rawCharacters is! List) {
      throw const SnapshotFormatException(
          'characters non è una lista');
    }

    final characters = <Character>[];
    for (final entry in rawCharacters) {
      if (entry is! Map) {
        throw const SnapshotFormatException(
            'un personaggio nell\'archivio non è un oggetto JSON');
      }
      try {
        characters.add(Character.fromMap(Map<String, dynamic>.from(entry)));
      } catch (_) {
        throw const SnapshotFormatException(
            'un personaggio nell\'archivio non è stato possibile leggerlo');
      }
    }
    return AppSnapshot(characters: characters);
  }
}
