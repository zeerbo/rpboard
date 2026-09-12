import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/migrations.dart';

/// Pure-Dart tests for [Migrations.stepsFrom] — no database opened, no I/O.
/// `test/providers/*_test.dart` is the prior art for this discipline: a plain
/// Dart test asserting behavior through a narrow seam, nothing more.
///
/// A synthetic four-step fake ladder drives every assertion below so
/// production DDL (`productionLadder`) is never touched by this file.
void main() {
  const fakeLadder = <MigrationStep>[
    MigrationStep(version: 1, statements: ['v1 stmt']),
    MigrationStep(version: 2, statements: ['v2 stmt a', 'v2 stmt b']),
    MigrationStep(version: 3, statements: ['v3 stmt']),
    MigrationStep(version: 4, statements: ['v4 stmt']),
  ];

  const migrations = Migrations(ladder: fakeLadder);

  test('returns the full ladder in ascending order starting from 0', () {
    final steps = migrations.stepsFrom(0, 4);

    expect(steps.map((s) => s.version), [1, 2, 3, 4]);
  });

  test('returns an empty list when oldVersion == newVersion', () {
    expect(migrations.stepsFrom(2, 2), isEmpty);
    expect(migrations.stepsFrom(0, 0), isEmpty);
    expect(migrations.stepsFrom(4, 4), isEmpty);
  });

  test('returns only the steps above oldVersion, in ascending order', () {
    final steps = migrations.stepsFrom(1, 4);

    expect(steps.map((s) => s.version), [2, 3, 4]);
  });

  test('never re-runs a step at or below oldVersion', () {
    final steps = migrations.stepsFrom(2, 4);

    expect(steps.any((s) => s.version <= 2), isFalse);
    expect(steps.map((s) => s.version), [3, 4]);
  });

  test('a partial upgrade stops at newVersion, leaving later steps unapplied', () {
    final steps = migrations.stepsFrom(0, 2);

    expect(steps.map((s) => s.version), [1, 2]);
  });

  test('preserves each step\'s ordered statement list untouched', () {
    final steps = migrations.stepsFrom(1, 2);

    expect(steps.single.statements, ['v2 stmt a', 'v2 stmt b']);
  });

  test('an unordered ladder is still returned in ascending version order', () {
    const shuffled = Migrations(
      ladder: [
        MigrationStep(version: 3, statements: ['c']),
        MigrationStep(version: 1, statements: ['a']),
        MigrationStep(version: 2, statements: ['b']),
      ],
    );

    expect(shuffled.stepsFrom(0, 3).map((s) => s.version), [1, 2, 3]);
  });

  group('production ladder', () {
    test('ships exactly four steps, versions 1 through 4', () {
      expect(productionLadder.length, 4);
      expect(productionLadder.map((s) => s.version), [1, 2, 3, 4]);
    });

    test('v1 holds the five baseline CREATE TABLE statements', () {
      final statements = productionLadder.first.statements;

      expect(statements.length, 5);
      expect(statements[0], contains('CREATE TABLE characters'));
      expect(statements[1], contains('CREATE TABLE campaigns'));
      expect(statements[2], contains('CREATE TABLE chapters'));
      expect(statements[3], contains('CREATE TABLE session_screens'));
      expect(statements[4], contains('CREATE TABLE components'));
    });

    test('v2 holds the armor and equipment ALTER TABLE statements', () {
      final statements = productionLadder[1].statements;

      expect(statements.length, 2);
      expect(statements[0], 'ALTER TABLE characters ADD COLUMN armor TEXT DEFAULT NULL');
      expect(statements[1], "ALTER TABLE characters ADD COLUMN equipment TEXT DEFAULT '[]'");
    });

    test('v3 holds the prepared-spell limit ALTER TABLE statement', () {
      final statements = productionLadder[2].statements;

      expect(statements.length, 1);
      expect(statements.single,
          'ALTER TABLE characters ADD COLUMN prepared_spells_max INTEGER DEFAULT 0');
    });

    test('v4 sweeps orphans from the three child tables, parents first', () {
      final statements = productionLadder[3].statements;

      expect(statements.length, 3);
      // The order is load-bearing, not cosmetic: deleting orphaned chapters
      // first is what turns their session_screens into orphans for the next
      // statement to catch, and likewise down to components. What the step
      // must never do is lean on ON DELETE CASCADE, which is why each
      // statement names its own parent table.
      expect(statements[0], contains('DELETE FROM chapters'));
      expect(statements[0], contains('FROM campaigns'));
      expect(statements[1], contains('DELETE FROM session_screens'));
      expect(statements[1], contains('FROM chapters'));
      expect(statements[2], contains('DELETE FROM components'));
      expect(statements[2], contains('FROM session_screens'));
      // NOT IN would yield no rows at all if any parent id were NULL, which
      // SQLite permits in a TEXT PRIMARY KEY.
      expect(statements.every((s) => s.contains('NOT EXISTS')), isTrue);
    });

    test('the released v1, v2 and v3 steps are untouched by later appends', () {
      // The ladder is append-only: adding a step must not have edited one an
      // installed database has already run.
      expect(productionLadder[0].version, 1);
      expect(productionLadder[0].statements.length, 5);
      expect(productionLadder[1].version, 2);
      expect(productionLadder[1].statements.length, 2);
      expect(productionLadder[2].version, 3);
      expect(productionLadder[2].statements.length, 1);
    });

    test('default Migrations() uses the production ladder', () {
      const migrations = Migrations();

      expect(migrations.stepsFrom(0, 4), productionLadder);
    });

    test('latestVersion equals the ladder\'s last step\'s version', () {
      const migrations = Migrations();

      // This is the single source of truth `openAppDatabase` requests its
      // schema version from — asserted here so appending a step to
      // `productionLadder` without touching anything else can never leave
      // the adapter requesting a stale version.
      expect(migrations.latestVersion, productionLadder.last.version);
      expect(migrations.latestVersion, 4);
    });
  });

  group('latestVersion', () {
    test('reads the last step of an arbitrary ladder, regardless of order', () {
      expect(migrations.latestVersion, 4); // fakeLadder above, sorted 1..4

      const shuffled = Migrations(
        ladder: [
          MigrationStep(version: 1, statements: ['a']),
          MigrationStep(version: 3, statements: ['c']),
          MigrationStep(version: 2, statements: ['b']),
        ],
      );
      // `latestVersion` reads `ladder.last`, not the maximum version — the
      // ladder is defined as already being in ascending, append-only order,
      // so this documents that the getter trusts that invariant rather than
      // re-sorting.
      expect(shuffled.latestVersion, 2);
    });
  });
}
