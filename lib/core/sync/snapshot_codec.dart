import 'dart:convert';

import '../../models/app_snapshot.dart';
import '../../models/character.dart';
import '../../models/campaign.dart';
import '../../models/chapter.dart';
import '../../models/session_screen.dart';
import '../../models/component.dart';

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
        'campaigns': snapshot.campaigns.map((c) => c.toMap()).toList(),
        'chapters': snapshot.chapters.map((c) => c.toMap()).toList(),
        'screens': snapshot.screens.map((s) => s.toMap()).toList(),
        'components': snapshot.components.map((c) => c.toMap()).toList(),
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

  /// Reads every one of [AppSnapshot]'s five lists from [payload]. Each is
  /// independently optional: an archive from before Campaign material was
  /// added to the format (ticket 02's) carries `characters` only, so
  /// `campaigns`/`chapters`/`screens`/`components` being absent decodes to an
  /// empty list rather than a refusal — the same tolerance the model layer's
  /// own `??` fallbacks already apply to a missing field within one entity.
  AppSnapshot _decodePayload(Map<String, dynamic> payload) {
    final characters = _decodeList(
      payload['characters'],
      'characters',
      'un personaggio',
      (m) => Character.fromMap(m),
    );
    final campaigns = _decodeList(
      payload['campaigns'],
      'campaigns',
      'una campagna',
      (m) => Campaign.fromMap(m),
    );
    final chapters = _decodeList(
      payload['chapters'],
      'chapters',
      'un capitolo',
      (m) => Chapter.fromMap(m),
    );
    final screens = _decodeList(
      payload['screens'],
      'screens',
      'una scena',
      (m) => SessionScreen.fromMap(m),
    );
    final components = _decodeList(
      payload['components'],
      'components',
      'un componente',
      (m) => SessionComponent.fromMap(m),
    );

    return AppSnapshot(
      characters: characters,
      campaigns: campaigns,
      chapters: chapters,
      screens: screens,
      components: components,
    );
  }

  /// Shared parsing for one of [AppSnapshot]'s lists: `null` (the field is
  /// entirely absent, as in an archive predating this list) decodes to an
  /// empty list; anything present but not a JSON array, or an entry that
  /// isn't an object or doesn't parse as [T], is refused with a
  /// [SnapshotFormatException] naming [fieldName]/[itemLabel] — never a
  /// partially-built list.
  List<T> _decodeList<T>(
    dynamic raw,
    String fieldName,
    String itemLabel,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    if (raw == null) return <T>[];
    if (raw is! List) {
      throw SnapshotFormatException('$fieldName non è una lista');
    }

    final result = <T>[];
    for (final entry in raw) {
      if (entry is! Map) {
        throw SnapshotFormatException(
            '$itemLabel nell\'archivio non è un oggetto JSON');
      }
      try {
        result.add(fromMap(Map<String, dynamic>.from(entry)));
      } catch (_) {
        throw SnapshotFormatException(
            '$itemLabel nell\'archivio non è stato possibile leggerlo');
      }
    }
    return result;
  }
}
