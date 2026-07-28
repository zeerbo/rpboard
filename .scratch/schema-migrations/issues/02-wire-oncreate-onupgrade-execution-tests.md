# 02 — Wire onCreate/onUpgrade onto the ladder, transactional upgrades, execution proof

**What to build:** `SqfliteDatabase`'s `onCreate` and `onUpgrade` hooks become thin callers of the Migrations module from ticket 01 instead of one hand-maintained DDL block with no upgrade counterpart: `onCreate` applies `stepsFrom(0, targetVersion)` and `onUpgrade` applies `stepsFrom(oldVersion, newVersion)` — the identical step-selection logic behind both, so a freshly installed database and a migrated one are built by the same code path and can never quietly drift apart. Each set of steps applied runs inside a single transaction, so a failure partway through leaves the database at its previous, working version instead of half-migrated. The inline DDL ticket 01 copied into the production ladder is deleted from `_onCreate`, leaving the ladder as the only source of schema DDL. This ticket also adds the repo's first test that opens a real SQLite database — an in-memory database via `sqflite_common_ffi`, driven by a test-owned fake three-step ladder (v1 → v2 → v3) injected into the module — proving the part of this PRD that actually protects a DM's and a player's data: a database opened at v1 with rows written into it, then reopened at v3, ends up at the v3 schema with those rows intact, and a database created from scratch at v3 has a schema identical to one upgraded there from v1. Production itself still ships only the single v1 baseline step from ticket 01 — no real user sees any change beyond the newly safe upgrade path sitting underneath it.

**Blocked by:** 01 — Migrations module: declarative step ladder + pure step selection (the module, `stepsFrom`, and the injectable ladder must exist first).

**Status:** done

- [x] `onCreate` calls the Migrations module with `stepsFrom(0, version)` — no DDL statement left inline in `SqfliteDatabase`
- [x] `onUpgrade` calls the Migrations module with `stepsFrom(oldVersion, newVersion)`
- [x] Each batch of steps applied for a given open (create or upgrade) executes inside a single transaction
- [x] A database created fresh at the top version and a database upgraded from v1 to the top version produce identical resulting schemas — asserted by a test that inspects both schemas, not by inspection of the source alone
- [x] Execution test opens an in-memory `sqflite_common_ffi` database (`sqfliteFfiInit()`, `databaseFactory = databaseFactoryFfi`, `inMemoryDatabasePath`), with the setup documented in the test file itself since no other test in the suite opens a real database yet
- [x] That test drives a test-owned fake v1 → v2 → v3 ladder injected into the module — not the production ladder
- [x] That test opens a database at v1, writes rows into it, reopens it at v3, and asserts both the resulting schema and the survival of the rows written before the upgrade
- [x] Test assertions are behavioral only — resulting schema shape and surviving row data, never call counts or intercepted SQL statements
- [x] The production ladder and schema version are unchanged from ticket 01 (still one step, version 1) — this ticket changes only how `onCreate`/`onUpgrade` reach the ladder, not what the ladder contains
- [x] `flutter analyze` clean; full `flutter test` suite green
