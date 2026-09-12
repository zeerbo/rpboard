import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/sync/version_policy.dart';

/// Pure, no-database tests for [SchemaVersionPolicy]. The policy is
/// asymmetric per the data-transfer PRD: an equal or lower archive
/// `schemaVersion` is accepted (an older archive imports, and the fields it
/// doesn't carry take the models' own defaults), a higher one is refused.
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

  // Ticket 02 shipped a strict interim policy under which this exact case —
  // a lower archive schemaVersion — was refused ("refused as older, for
  // now"). This ticket relaxes that half of the policy: an older archive now
  // imports, relying on the default-tolerance the models already have, so
  // this assertion is updated from `refusedOlder` to `accepted` rather than
  // left pinning the interim behaviour.
  test('a lower archive schemaVersion is accepted', () {
    final outcome =
        policy.evaluate(localSchemaVersion: 4, archiveSchemaVersion: 3);

    expect(outcome, SchemaVersionOutcome.accepted);
  });

  test('the newer-refusal message tells the user to update this installation', () {
    final message =
        policy.refusalMessage(localSchemaVersion: 4, archiveSchemaVersion: 5);

    expect(message.toLowerCase(), contains('aggiorna'));
  });

  // Was "the older-refusal message names both versions": with `refusedOlder`
  // gone, the only refusal left is the newer-schema one, and it is the one
  // that should name both versions so the user can see exactly how far out
  // of date this installation is.
  test('the newer-refusal message names both versions', () {
    final message =
        policy.refusalMessage(localSchemaVersion: 4, archiveSchemaVersion: 5);

    expect(message, contains('5'));
    expect(message, contains('4'));
  });
}
