import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/sync/version_policy.dart';

/// Pure, no-database tests for [SchemaVersionPolicy]. Ticket 02's policy is
/// deliberately strict — only an exact match is accepted; both a lower and a
/// higher `schemaVersion` are refused. A later ticket relaxes the lower case
/// to accept it; this file documents today's narrower behaviour so that
/// relaxation is a visible, deliberate change to this test, not a surprise.
void main() {
  const policy = SchemaVersionPolicy();

  test('an equal schemaVersion is accepted', () {
    final outcome =
        policy.evaluate(localSchemaVersion: 4, archiveSchemaVersion: 4);

    expect(outcome, SchemaVersionOutcome.accepted);
  });

  test('a higher archive schemaVersion is refused as newer', () {
    final outcome =
        policy.evaluate(localSchemaVersion: 4, archiveSchemaVersion: 5);

    expect(outcome, SchemaVersionOutcome.refusedNewer);
  });

  test('a lower archive schemaVersion is refused as older, for now', () {
    final outcome =
        policy.evaluate(localSchemaVersion: 4, archiveSchemaVersion: 3);

    expect(outcome, SchemaVersionOutcome.refusedOlder);
  });

  test('the newer-refusal message tells the user to update this installation', () {
    final message =
        policy.refusalMessage(localSchemaVersion: 4, archiveSchemaVersion: 5);

    expect(message.toLowerCase(), contains('aggiorna'));
  });

  test('the older-refusal message names both versions', () {
    final message =
        policy.refusalMessage(localSchemaVersion: 4, archiveSchemaVersion: 3);

    expect(message, contains('3'));
    expect(message, contains('4'));
  });
}
