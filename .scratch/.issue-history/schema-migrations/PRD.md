Status: ready-for-agent

# A migration ladder for the SQLite schema

Implements architecture-review candidate **C6** (`docs/architecture-review.html#c6`). A new ADR-0005 should record the accepted decision this PRD implements; it relates to [ADR-0002](../../docs/adr/0002-database-seam.md), which named this the seam's prerequisite work, and to [ADR-0001](../../docs/adr/0001-typed-component-data.md), whose frozen `dbKey` strings exist specifically because this migration path did not.

## Problem Statement

Every Campaign, Chapter, SessionScreen, SessionComponent, and Character a DM or player has built lives in one SQLite file on their device, opened today at schema version 1 through a single `onCreate` with no `onUpgrade`. That file already exists on real machines. The day the schema needs to change — a new column, a new table, a renamed `dbKey` as ADR-0001 anticipates — `SqfliteDatabase` has no way to carry an existing database forward. Bumping the schema version with no `onUpgrade` defined makes `sqflite` throw as soon as it opens a database whose on-disk version disagrees with the requested one, so the app fails to start at all: every campaign the DM has prepared and every character sheet a player has filled in becomes unreachable behind a crash. Leaving the version unbumped instead lets the old schema stay in place while the new code assumes columns or tables that were never created, so the first query touching the new shape crashes just the same, only later and less predictably. Either way, a schema change made by a developer becomes data loss or an unusable app for someone who did nothing but install an update. ADR-0001 already reacted to this gap by freezing the `dbKey` strings persisted in `components.type` — a decision it only had to make because no migration path existed to make renaming one safe.

## Solution

Give `SqfliteDatabase` a real `onUpgrade` path so a schema change carries a DM's and a player's existing data forward instead of destroying it. A `Migrations` module owns an ordered ladder of steps, where a step is nothing more than a schema version and the SQL statements that bring a database from the version below it up to that one. Deciding which steps apply between an old and a new version is a pure function with no database involved, so the logic that decides what runs can be tested to exhaustion before it ever touches a real file. `onCreate` and `onUpgrade` both become thin callers of that same ladder — one applies every step from scratch, the other applies every step above whatever version is already on disk — so a freshly installed database and a migrated one are always built by the identical code path and can never quietly drift apart.

This PRD ships the mechanism only. The current `onCreate` DDL becomes the ladder's first step, the schema version stays at 1, and today's users see no difference at all. What changes is that the next time a table needs a new column, or a `dbKey` needs to be renamed, the app has a proven, tested path to carry the DM's campaigns and the player's characters through that change intact, instead of losing them or locking their owner out at launch.

## User Stories

1. As a developer, I want a `Migrations` module that owns an ordered ladder of versioned steps, so that schema changes have one documented home instead of being invented ad hoc inside `onCreate`.
2. As a developer, I want each step to be declarative — a version number plus an ordered list of SQL statements — so that a step can be read and tested without opening any database connection.
3. As a developer, I want `stepsFrom(oldVersion, newVersion)` to be a pure function, so that I can test exactly which steps run for any pair of versions with no database open at all.
4. As a developer, I want `onCreate` redefined as "apply every step from 0", so that a freshly created database is built by the exact same code path a migrated one goes through, with no second DDL source to keep in sync.
5. As a developer, I want `onUpgrade` redefined as "apply every step above the old version", so that upgrading an existing database reuses the identical step-selection logic `onCreate` uses, rather than a hand-maintained second path.
6. As a developer, I want the step ladder injectable into the `Migrations` module, defaulting to the real production ladder, so that tests can drive a short fake ladder without touching production DDL.
7. As a developer, I want each upgrade to run inside a single transaction, so that a failure partway through leaves the database at its previous, working version instead of half-migrated and unusable.
8. As a developer, I want production to ship exactly one step — the current v1 DDL as the baseline — with the schema version staying at 1, so that this change is invisible to every existing user while the mechanism itself is fully proven out.
9. As a developer, I want pure-Dart tests asserting that `stepsFrom` returns the right steps in ascending order, is empty when the versions match, covers the full ladder when starting from 0, and never re-runs a step that's already been applied, so that step selection is verified with zero I/O.
10. As a developer, I want at least one execution test that runs the `Migrations` module against a real SQLite database opened in memory via `sqflite_common_ffi`, driven by a test-owned fake ladder, so that the part of this change that can actually destroy user data — a transaction executing SQL against a live file — is verified, not just the selection logic sitting in front of it.
11. As a developer, I want that execution test to open a database at an old version, write rows into it, then reopen it at a newer version and assert the resulting schema and the survival of those rows, so that the test proves data really does carry through an upgrade rather than merely that some SQL ran.
12. As a developer, I want that same test to confirm that creating a database from scratch at the top version produces the identical schema an upgrade from v1 produces, so that `onCreate` and `onUpgrade` are proven to never drift apart, not just asserted to share code by inspection.
13. As a developer picking up a future schema change, I want to add one step to the ladder and trust that `onCreate` and `onUpgrade` both pick it up automatically, so that shipping a schema change stops being a bespoke, risky event and becomes a routine addition.
14. As a DM, I want every Campaign, Chapter, SessionScreen, and SessionComponent I've already built to still be there the next time the app updates, so that a developer's schema change never costs me the sessions I've prepared.
15. As a player, I want my Character sheet — ability scores, inventory, spells, notes, everything — to survive an app update untouched, so that an internal database change is completely invisible to me.
16. As a DM or player, I want the app to open normally after an update instead of crashing on launch, so that a schema change on the developer's side never locks me out of my own data.
17. As a developer maintaining ADR-0001's frozen `dbKey` strings, I want a working, tested migration path to exist, so that renaming a `dbKey` later becomes something the team can actually do, instead of something the ADR forbids purely for lack of a way to do it safely.

## Implementation Decisions

- **One `Migrations` module, declarative steps.** A step is a schema version plus an ordered list of SQL statements — no Dart callback receiving a connection. The module lives inside the SQLite adapter, below the `Database` seam.
- **Rejected: callback-shaped steps.** A step defined as a Dart function receiving the open connection was rejected — it couples the module to `sqflite` directly and kills the ability to test step selection with no database open.
- **Rejected: a hybrid declarative-plus-callback shape.** Supporting both a SQL-statement list and a callback per step was rejected as premature — it gives two ways to write a migration on day one with no concrete case yet demanding the callback form.
- **Known limitation of the declarative shape, stated plainly.** A migration that needs Dart-side transformation of existing data — for example, rewriting the JSON payload inside a `components` row — does not fit this shape today. Plain DDL and row-level SQL `UPDATE`/backfill statements do. The shape is extended when a real case demands it, not speculatively ahead of one.
- **`stepsFrom(oldVersion, newVersion)` is pure.** It takes two version numbers and returns an ordered list of steps; it never touches a database, which is what makes it testable with no I/O at all.
- **`onCreate` and `onUpgrade` unified on the same ladder.** `onCreate` becomes "apply every step from 0"; `onUpgrade` becomes "apply every step above the old version." One code path builds both a fresh database and a migrated one, which is the property that matters most here — a freshly created database and an upgraded one can never quietly diverge.
- **The current `_onCreate` DDL becomes the baseline step, version 1.** All five existing `CREATE TABLE` statements move into the ladder unchanged as the first step.
- **The step ladder is injectable.** The `Migrations` module takes the ladder as a parameter, defaulting to the real production ladder. Production ships exactly one step — the v1 baseline — and the schema version stays at 1; no schema change is made by this PRD.
- **Rejected: shipping a real v2 change to exercise the code.** Adding an actual schema change nobody asked for, purely to prove the mechanism, was rejected as scope creep with no user-facing justification.
- **Rejected: testing step selection only.** Verifying only `stepsFrom` and skipping execution against a real database was rejected because it leaves the part of the system that can actually destroy user data — the transaction running SQL against a live file — unverified.
- **Each upgrade runs inside a single transaction.** A failed migration leaves the database at its previous version rather than half-migrated, so a broken upgrade fails safely instead of corrupting the file.
- **Migrations stay below the `Database` seam.** They live entirely inside `SqfliteDatabase`; `InMemoryDatabase` has no schema and is unaffected, and the `Database` interface itself does not change.

## Testing Decisions

- **Two layers.** First, pure-Dart tests on step selection and ordering, with no database opened at all: `stepsFrom` returns the right steps in ascending order, returns an empty list when the versions already match, covers the full ladder when starting from 0, and never re-runs a step that's already been applied.
- **Second, an execution test against a real SQLite database.** Opened in memory via `sqflite_common_ffi` (`databaseFactoryFfi` and `inMemoryDatabasePath`), driven by a test-owned fake ladder (v1 → v2 → v3) injected into the module: open a database at v1, write rows into it, reopen it at v3, and assert that the upgrade ran starting from the right version, that the resulting schema matches what v3 should look like, and that the rows written before the upgrade survived it.
- **Also assert the no-drift property directly.** Creating a database from scratch at the top version must yield the same schema as upgrading a v1 database up to it — this is the concrete check that `onCreate` and `onUpgrade` sharing one ladder actually holds, not just that it reads that way in the code.
- **Assert observable outcomes only.** Resulting schema shape and surviving row data — never that a particular SQL statement was executed. A test that checks call counts or intercepts specific statements would pass against a broken migration that happens to call the right methods.
- **Prior art and a note for whoever writes this.** `test/providers/*_test.dart` is the prior art for the pure-Dart, no-Flutter discipline used for the first layer. The execution test is the repo's first test that opens a real SQLite database at all — document the `sqflite_common_ffi` setup (`sqfliteFfiInit()`, `databaseFactory = databaseFactoryFfi`, `inMemoryDatabasePath`) clearly in the test file, since nothing else in the suite does this yet.

## Out of Scope

- Any actual schema change or a real v2 step — this PRD ships the mechanism with a single v1 baseline step and leaves the schema version at 1.
- Dart-side data transformations inside a step (for example, rewriting a JSON payload embedded in a `components` row) — the declarative shape doesn't support this yet; it's added when a real case demands it.
- Downgrade or rollback support — the ladder only ever moves forward.
- Backup or export of the user's database file.
- Any change to the `Database` seam interface — `InMemoryDatabase` and the seam contract are untouched; migrations live entirely inside `SqfliteDatabase`.
- Renaming any persisted `dbKey` — this PRD only makes that possible later; the rename itself is separate work for whoever picks it up.

## Further Notes

- Depends on C2 (done — ADR-0002), which named this PRD as one of the changes it unblocks. Recommended sequence per the architecture review: C1 → C5 → C3 → C4 → **C6** → C7.
- Sharpest risk to watch during implementation: the no-drift property between `onCreate` and `onUpgrade`. It's easy to write a `Migrations` module where the two paths merely look identical in the source but diverge in practice (e.g. one skipping a step the other includes) — the create-from-scratch-versus-upgraded-schema assertion in the execution test exists specifically to catch that.
- This PRD does not touch ADR-0001's frozen `dbKey` strings. It only removes the reason they had to be frozen in the first place — a future PRD can spend that unlock if a `dbKey` ever needs to change.
