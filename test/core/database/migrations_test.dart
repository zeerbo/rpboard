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
    test('ships exactly one step, version 1', () {
      expect(productionLadder.length, 1);
      expect(productionLadder.single.version, 1);
    });

    test('holds the five baseline CREATE TABLE statements', () {
      final statements = productionLadder.single.statements;

      expect(statements.length, 5);
      expect(statements[0], contains('CREATE TABLE characters'));
      expect(statements[1], contains('CREATE TABLE campaigns'));
      expect(statements[2], contains('CREATE TABLE chapters'));
      expect(statements[3], contains('CREATE TABLE session_screens'));
      expect(statements[4], contains('CREATE TABLE components'));
    });

    test('default Migrations() uses the production ladder', () {
      const migrations = Migrations();

      expect(migrations.stepsFrom(0, 1), productionLadder);
    });
  });
}
