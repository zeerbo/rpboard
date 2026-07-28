import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;

/// A single, versioned migration step: a schema version plus the ordered SQL
/// statements that carry a database from the version below it up to this one.
///
/// Declarative only — a version number and plain SQL, no Dart callback
/// receiving a connection and no hybrid escape hatch. That is what makes a
/// step readable and testable with zero I/O: it is data, not behavior.
class MigrationStep {
  const MigrationStep({required this.version, required this.statements});

  /// The schema version this step brings the database up to.
  final int version;

  /// SQL statements applied, in order, to go from `version - 1`-ish (in
  /// practice: from whatever the previous applied step left behind) to
  /// [version].
  final List<String> statements;
}

/// The production schema ladder. Ships exactly one step today — the baseline
/// v1 DDL, moved verbatim out of `SqfliteDatabase`'s former `_onCreate` — so
/// the schema version stays at 1 and this change is invisible to every
/// existing install. The next schema change adds a step here; `onCreate` and
/// `onUpgrade` pick it up automatically since both are thin callers of
/// [Migrations.stepsFrom].
const List<MigrationStep> productionLadder = <MigrationStep>[
  MigrationStep(
    version: 1,
    statements: <String>[
      '''
      CREATE TABLE characters (
        id TEXT PRIMARY KEY,
        name TEXT DEFAULT '',
        player_name TEXT DEFAULT '',
        race TEXT DEFAULT '',
        character_class TEXT DEFAULT '',
        subclass TEXT DEFAULT '',
        level INTEGER DEFAULT 1,
        background TEXT DEFAULT '',
        alignment TEXT DEFAULT '',
        experience_points INTEGER DEFAULT 0,
        strength INTEGER DEFAULT 10,
        dexterity INTEGER DEFAULT 10,
        constitution INTEGER DEFAULT 10,
        intelligence INTEGER DEFAULT 10,
        wisdom INTEGER DEFAULT 10,
        charisma INTEGER DEFAULT 10,
        hp_max INTEGER DEFAULT 0,
        hp_current INTEGER DEFAULT 0,
        hp_temp INTEGER DEFAULT 0,
        armor_class INTEGER DEFAULT 10,
        initiative_bonus INTEGER DEFAULT 0,
        speed INTEGER DEFAULT 30,
        hit_dice TEXT DEFAULT '1d8',
        hit_dice_used INTEGER DEFAULT 0,
        has_inspiration INTEGER DEFAULT 0,
        saving_throw_profs TEXT DEFAULT '[]',
        skill_profs TEXT DEFAULT '[]',
        skill_expertise TEXT DEFAULT '[]',
        death_save_successes INTEGER DEFAULT 0,
        death_save_failures INTEGER DEFAULT 0,
        is_dead INTEGER DEFAULT 0,
        is_stable INTEGER DEFAULT 0,
        inventory TEXT DEFAULT '[]',
        cp INTEGER DEFAULT 0,
        sp INTEGER DEFAULT 0,
        ep INTEGER DEFAULT 0,
        gp INTEGER DEFAULT 0,
        pp INTEGER DEFAULT 0,
        personality_traits TEXT DEFAULT '',
        ideals TEXT DEFAULT '',
        bonds TEXT DEFAULT '',
        flaws TEXT DEFAULT '',
        features_and_traits TEXT DEFAULT '',
        profs_and_languages TEXT DEFAULT '',
        backstory TEXT DEFAULT '',
        appearance TEXT DEFAULT '',
        age INTEGER DEFAULT 0,
        height TEXT DEFAULT '',
        weight TEXT DEFAULT '',
        eyes TEXT DEFAULT '',
        skin TEXT DEFAULT '',
        hair TEXT DEFAULT '',
        attacks TEXT DEFAULT '[]',
        spellcasting_ability TEXT DEFAULT '',
        spell_slots TEXT DEFAULT '[]',
        spells TEXT DEFAULT '[]',
        notes TEXT DEFAULT ''
      )
    ''',
      '''
      CREATE TABLE campaigns (
        id TEXT PRIMARY KEY,
        name TEXT DEFAULT '',
        description TEXT DEFAULT '',
        setting TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''',
      '''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        campaign_id TEXT NOT NULL,
        title TEXT DEFAULT '',
        summary TEXT DEFAULT '',
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE
      )
    ''',
      '''
      CREATE TABLE session_screens (
        id TEXT PRIMARY KEY,
        chapter_id TEXT NOT NULL,
        title TEXT DEFAULT '',
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
      )
    ''',
      '''
      CREATE TABLE components (
        id TEXT PRIMARY KEY,
        screen_id TEXT NOT NULL,
        type TEXT NOT NULL,
        order_index INTEGER DEFAULT 0,
        data TEXT DEFAULT '{}',
        FOREIGN KEY (screen_id) REFERENCES session_screens(id) ON DELETE CASCADE
      )
    ''',
    ],
  ),
];

/// Owns the ordered, append-only ladder of schema migration steps and
/// selects which ones apply between any two schema versions. The ladder is
/// injectable — defaulting to [productionLadder] — so tests can drive a
/// short fake ladder without touching production DDL.
///
/// [stepsFrom] is pure: two version numbers in, an ordered list of steps
/// out, no database touched. That is what lets step selection be tested to
/// exhaustion before any SQL ever runs against a real file. [apply] is the
/// sibling that actually executes the selected steps against a live
/// connection, inside a single transaction; `SqfliteDatabase`'s `onCreate`
/// and `onUpgrade` are both thin callers of it, so a freshly created
/// database and a migrated one are always built by the identical code path.
class Migrations {
  const Migrations({this.ladder = productionLadder});

  /// The ordered ladder of steps this module selects from. Defaults to
  /// [productionLadder]; tests inject a short fake ladder instead.
  final List<MigrationStep> ladder;

  /// The steps that carry a database from [oldVersion] to [newVersion], in
  /// ascending version order. Empty when [oldVersion] already equals
  /// [newVersion]. Never includes a step at or below [oldVersion] — an
  /// already-applied step is never re-run.
  List<MigrationStep> stepsFrom(int oldVersion, int newVersion) {
    final applicable = ladder
        .where((step) => step.version > oldVersion && step.version <= newVersion)
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    return applicable;
  }

  /// Applies every step from [oldVersion] up to [newVersion], in order,
  /// against [db]. All statements from all applicable steps run inside a
  /// single transaction, so a failure partway through leaves the database at
  /// its previous, working version instead of half-migrated. A no-op — no
  /// transaction opened at all — when [stepsFrom] returns nothing.
  Future<void> apply(sql.Database db, int oldVersion, int newVersion) async {
    final steps = stepsFrom(oldVersion, newVersion);
    if (steps.isEmpty) return;
    await db.transaction((txn) async {
      for (final step in steps) {
        for (final statement in step.statements) {
          await txn.execute(statement);
        }
      }
    });
  }
}
