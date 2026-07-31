import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;
import 'package:rpboard/core/database/migrations.dart';

/// The repo's first test that opens a real SQLite database.
///
/// Every other test in this suite (`test/models/component_test.dart`, the
/// `test/providers/*_test.dart` family) is pure Dart with no I/O, exercising
/// production code through the [Migrations.stepsFrom] pure function or the
/// `InMemoryDatabase` fake. Step *selection* is fully covered that way. What
/// it cannot prove is that a transaction executing real SQL against a real
/// file actually carries a DM's or a player's data through an upgrade — that
/// is the risk this file exists to close.
///
/// ### sqflite_common_ffi setup
///
/// `sqflite` normally talks to the platform's native SQLite bindings via a
/// method channel, which only exists inside a running app. `sqflite_common_ffi`
/// swaps that for a direct FFI binding to SQLite, so a database can be opened
/// from a plain `flutter test` process with no device or emulator involved:
///
/// - `sqfliteFfiInit()` — loads the native `sqlite3` library the ffi package
///   binds to. Must run once before any ffi database is opened.
/// - `databaseFactory = databaseFactoryFfi` — points `sqflite`'s top-level
///   `openDatabase`/factory machinery at the ffi implementation instead of the
///   (here, absent) platform channel.
/// - `inMemoryDatabasePath` — the special path (`:memory:`) that opens a
///   throwaway in-memory SQLite database instead of a file on disk. No
///   cleanup needed between tests.
///
/// ### Why "reopen" is simulated on the same connection, not a literal close
///
/// A real device upgrade closes the app (killing the old connection) and
/// reopens the *same on-disk file* at a new requested version; `sqflite`
/// itself detects the version mismatch and dispatches `onUpgrade`. An
/// in-memory SQLite database has no disk backing, so closing the connection
/// destroys the data — there is no file left to reopen. Simulating a literal
/// close/reopen here would therefore prove nothing about data survival; it
/// would just recreate an empty database.
///
/// Instead, each test keeps the same live connection (standing in for "the
/// same file") and calls [Migrations.apply] a second time with the old and
/// new versions — the exact call `SqfliteDatabase._onUpgrade` makes when
/// `sqflite` invokes it during a real reopen. `sqflite`'s own version
/// detection and hook dispatch is well-tested library code that this PRD
/// doesn't touch; what these tests verify is the part this PRD adds: that
/// applying the selected steps against a live, already-populated connection
/// carries the data through and lands on the right schema.
void main() {
  // Runs once for the whole file: loads the native sqlite3 bindings and
  // points sqflite's factory at the ffi implementation.
  sql.sqfliteFfiInit();
  sql.databaseFactory = sql.databaseFactoryFfi;

  // A test-owned fake ladder — v1 -> v2 -> v3 — completely separate from
  // `productionLadder`, per the PRD: execution tests must not touch
  // production DDL.
  const fakeLadder = <MigrationStep>[
    MigrationStep(
      version: 1,
      statements: [
        '''
        CREATE TABLE items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
        ''',
      ],
    ),
    MigrationStep(
      version: 2,
      statements: [
        "ALTER TABLE items ADD COLUMN description TEXT NOT NULL DEFAULT ''",
      ],
    ),
    MigrationStep(
      version: 3,
      statements: [
        '''
        CREATE TABLE tags (
          id TEXT PRIMARY KEY,
          item_id TEXT NOT NULL,
          label TEXT NOT NULL DEFAULT ''
        )
        ''',
      ],
    ),
  ];

  const migrations = Migrations(ladder: fakeLadder);

  /// Opens a fresh, independent in-memory database. `singleInstance: false`
  /// so multiple independent in-memory databases can be open at once within
  /// one test — by default `sqflite` caches connections by path, and every
  /// in-memory database shares the same magic path, so the default would
  /// hand back the same cached connection instead of a new one.
  Future<sql.Database> openFresh({
    required int version,
    required Future<void> Function(sql.Database db, int version) onCreate,
  }) {
    return sql.databaseFactoryFfi.openDatabase(
      sql.inMemoryDatabasePath,
      options: sql.OpenDatabaseOptions(
        version: version,
        onCreate: onCreate,
        singleInstance: false,
      ),
    );
  }

  /// The DDL sqlite actually stored for every user table, keyed by table
  /// name. `sqlite_master.sql` reflects a table's *current* shape, including
  /// columns added later via `ALTER TABLE ... ADD COLUMN` — so comparing this
  /// map between two databases is a direct check of "do these two schemas
  /// actually match", not an inspection of which steps ran.
  Future<Map<String, String>> schemaOf(sql.Database db) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name', 'sql'],
      where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    return {for (final row in rows) row['name'] as String: row['sql'] as String};
  }

  test(
    'upgrading from v1 to v3 reaches the v3 schema and keeps pre-upgrade rows',
    () async {
      final db = await openFresh(
        version: 1,
        onCreate: (db, version) => migrations.apply(db, 0, version),
      );
      addTearDown(db.close);

      await db.insert('items', {'id': 'i1', 'name': 'Longsword'});

      // Simulate the app reopening this database at v3 (see file doc above
      // for why this calls migrations.apply directly instead of literally
      // closing and reopening the connection).
      await migrations.apply(db, 1, 3);

      // Schema reached v3: the v2 column exists, and the v3 table exists.
      final itemsInfo = await db.rawQuery('PRAGMA table_info(items)');
      expect(
        itemsInfo.map((c) => c['name']),
        containsAll(['id', 'name', 'description']),
      );
      final tables = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name = 'tags'",
      );
      expect(tables, hasLength(1));

      // The row written before the upgrade survived it, backfilled with the
      // v2 column's default.
      final rows = await db.query('items', where: "id = 'i1'");
      expect(rows.single['name'], 'Longsword');
      expect(rows.single['description'], '');
    },
  );

  test(
    'never re-runs an already-applied step (v1 CREATE TABLE would error on a second run)',
    () async {
      final db = await openFresh(
        version: 1,
        onCreate: (db, version) => migrations.apply(db, 0, version),
      );
      addTearDown(db.close);

      await db.insert('items', {'id': 'i1', 'name': 'Shield'});

      // If stepsFrom incorrectly re-included the v1 step, this would throw
      // ("table items already exists") instead of applying only v2 and v3.
      await expectLater(migrations.apply(db, 1, 3), completes);
    },
  );

  test(
    'no drift: a database created fresh at v3 has the identical schema an '
    'upgrade from v1 to v3 produces',
    () async {
      final upgraded = await openFresh(
        version: 1,
        onCreate: (db, version) => migrations.apply(db, 0, version),
      );
      addTearDown(upgraded.close);
      await upgraded.insert('items', {'id': 'i1', 'name': 'Potion'});
      await migrations.apply(upgraded, 1, 3);

      final fresh = await openFresh(
        version: 3,
        onCreate: (db, version) => migrations.apply(db, 0, version),
      );
      addTearDown(fresh.close);

      expect(await schemaOf(upgraded), await schemaOf(fresh));
    },
  );

  group('armor/equipment v1 -> v2 (ticket 01)', () {
    // A second, test-owned fake ladder mimicking the real characters-table
    // shape: a v1 CREATE TABLE, then a v2 step adding the same two ALTER
    // statements productionLadder's v2 step adds. Kept separate from the
    // three-step fakeLadder above (and from productionLadder) so this group
    // reads standalone.
    const armorLadder = <MigrationStep>[
      MigrationStep(
        version: 1,
        statements: [
          '''
          CREATE TABLE characters (
            id TEXT PRIMARY KEY,
            name TEXT DEFAULT ''
          )
          ''',
        ],
      ),
      MigrationStep(
        version: 2,
        statements: [
          'ALTER TABLE characters ADD COLUMN armor TEXT DEFAULT NULL',
          "ALTER TABLE characters ADD COLUMN equipment TEXT DEFAULT '[]'",
        ],
      ),
    ];

    const armorMigrations = Migrations(ladder: armorLadder);

    test(
      'upgrading a v1 characters row to v2 keeps the row and adds armor/equipment with correct defaults',
      () async {
        final db = await openFresh(
          version: 1,
          onCreate: (db, version) => armorMigrations.apply(db, 0, version),
        );
        addTearDown(db.close);

        await db.insert('characters', {'id': 'pg1', 'name': 'Aria'});

        await armorMigrations.apply(db, 1, 2);

        final columns = await db.rawQuery('PRAGMA table_info(characters)');
        expect(
          columns.map((c) => c['name']),
          containsAll(['id', 'name', 'armor', 'equipment']),
        );

        final rows = await db.query('characters', where: "id = 'pg1'");
        expect(rows.single['name'], 'Aria');
        expect(rows.single['armor'], isNull);
        expect(rows.single['equipment'], '[]');
      },
    );

    test(
      'no drift: a fresh v2 characters table matches one upgraded from v1',
      () async {
        final upgraded = await openFresh(
          version: 1,
          onCreate: (db, version) => armorMigrations.apply(db, 0, version),
        );
        addTearDown(upgraded.close);
        await upgraded.insert('characters', {'id': 'pg1', 'name': 'Aria'});
        await armorMigrations.apply(upgraded, 1, 2);

        final fresh = await openFresh(
          version: 2,
          onCreate: (db, version) => armorMigrations.apply(db, 0, version),
        );
        addTearDown(fresh.close);

        expect(await schemaOf(upgraded), await schemaOf(fresh));
      },
    );
  });
}
