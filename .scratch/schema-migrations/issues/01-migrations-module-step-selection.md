# 01 — Migrations module: declarative step ladder + pure step selection

**What to build:** A `Migrations` module, living inside the SQLite adapter below the `Database` seam, that owns an ordered, append-only ladder of migration steps and exposes a pure `stepsFrom(oldVersion, newVersion)` function selecting which steps apply between any two schema versions. A step is a plain declarative shape — a schema version number plus an ordered list of SQL statements — with no Dart callback and no database connection anywhere near it, so the module can be built and interrogated with zero I/O. The ladder is a constructor parameter of the module, defaulting to the real production ladder; that production ladder ships with exactly one step, version 1, holding the five `CREATE TABLE` statements moved verbatim out of `SqfliteDatabase`'s current `_onCreate`. This ticket is the prefactor only — nothing wires the module into `SqfliteDatabase` yet, `onCreate`/`onUpgrade` are untouched, the schema version stays at 1, and the app's behavior is unchanged. Ticket 02 does the actual switchover.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] `Migrations` module declares a step shape: a version number plus an ordered list of SQL statements — no Dart callback receiving a connection, no hybrid escape hatch
- [x] `stepsFrom(oldVersion, newVersion)` is a pure function — no database open, no I/O, callable from a plain Dart test with nothing but two integers
- [x] `stepsFrom` returns the applicable steps in ascending version order
- [x] `stepsFrom` returns an empty list when `oldVersion == newVersion`
- [x] `stepsFrom(0, newVersion)` returns the full ladder from scratch
- [x] `stepsFrom` never returns a step whose version is at or below `oldVersion` (an already-applied step is never re-run)
- [x] The ladder is injectable into `Migrations`, defaulting to the real production ladder, so tests can drive a short fake ladder without touching production DDL
- [x] Production ladder holds exactly one step, version 1, containing the five `CREATE TABLE` statements currently inline in `SqfliteDatabase._onCreate`, moved verbatim — no statement reworded or reordered
- [x] `SqfliteDatabase._onCreate`/`onUpgrade` behavior is untouched by this ticket — no wiring into the module yet, schema version stays at 1, the app runs identically to before
- [x] Pure-Dart tests cover every rule above using a synthetic multi-step fake ladder, with zero database or I/O involved (`test/providers/*_test.dart` is the prior art for this discipline)
- [x] `flutter analyze` and `flutter test` clean
