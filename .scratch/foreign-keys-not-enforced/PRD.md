# Foreign keys are not enforced

Status: done

## Problem Statement

A DM who deletes a Campaign expects it gone — the Campaign and everything they prepared under it.
What actually happened is that the Campaign row disappeared and its Chapters, SessionScreens and
SessionComponents stayed on disk forever, invisible: no screen in the app can reach them, because
every read descends from a parent id.

The schema had said otherwise since the v1 DDL. `chapters`, `session_screens` and `components` each
declared `FOREIGN KEY … ON DELETE CASCADE`. Nothing ever enabled enforcement, and SQLite leaves
foreign keys off by default, per connection. So the declaration was decorative for the whole life of
the schema, and a second defect rode along with the first: a child row referencing a parent that
does not exist was accepted without complaint.

Nobody would have noticed from the app. The symptom is a database that quietly grows rows no user
can see, and constraints that describe a database this is not.

## Solution

Enforce foreign keys on every connection the app opens, and delete the rows already orphaned.

Enforcement goes in the connection's configure hook rather than a migration step, because the
setting is per-connection state and not schema — a step would have protected exactly one launch.
Migration step 4 sweeps the existing orphans: Chapters with no Campaign, then SessionScreens with no
Chapter, then SessionComponents with no SessionScreen. Nothing a DM could see is removed.

The change is also an opportunity taken: how the app opens its database is now a named function a
test can call, so "the app enforces foreign keys" is assertable rather than inspectable. The defect
survived this long precisely because no test could observe the app's own connection configuration.

## User Stories

1. As a DM, I want deleting a Campaign to remove its Chapters, SessionScreens and SessionComponents,
   so that deleting means deleting.
2. As a DM, I want deleting a Chapter to remove its SessionScreens and their SessionComponents, so
   that pruning one arc of a Campaign does not leave its prepared Scene behind.
3. As a DM, I want deleting a SessionScreen to remove its SessionComponents, so that nothing I
   composed on a Scene outlives it.
4. As a DM, I want the rows orphaned by past deletions swept out, so that my database stops carrying
   material I deleted and can no longer see.
5. As a DM, I want my own visible Campaigns, Chapters, SessionScreens and SessionComponents left
   untouched by that sweep, so that a cleanup cannot cost me prepared work.
6. As a player, I want my Characters unaffected, so that a fix to Master Mode's storage cannot touch
   my sheet.
7. As a developer, I want a child row with a non-existent parent id rejected at write time, so that
   an id bug surfaces immediately instead of producing rows nobody can reach.
8. As a developer, I want enforcement to hold on every launch, not only the one where a migration
   ran, so that the guarantee is not a one-off.
9. As a developer, I want how the app opens its database to be callable from a test, so that
   connection configuration can be asserted rather than read and hoped about.
10. As a developer, I want the in-memory fake to refuse what the real adapter refuses, so that tests
    cannot pass against behaviour production no longer has.

## Implementation Decisions

- **Enforcement lives in the connection's configure hook, not a migration step.** Verified twice
  rather than assumed: `sqflite_common`'s documented hook order runs configure first, before the
  version check and outside the version-change transaction — which matters, since SQLite treats the
  pragma as a no-op inside a transaction — and a test asserts that a database reopened after the
  pragma was set reads it back as off.
- **The app's open path became a named, path-taking function.** Version, configure hook and ladder
  wiring in one place; the adapter resolves the on-device path and calls it. Only the path varies,
  so a test opens a throwaway database configured exactly as production is.
- **Migration step 4 deletes orphans, parents first, without leaning on the cascade** it exists to
  make honest: removing orphaned Chapters is what turns their SessionScreens into orphans for the
  next statement. The predicate is `NOT EXISTS`, not `NOT IN`, which would match nothing at all if a
  parent id were NULL — SQLite permits NULL in a TEXT PRIMARY KEY.
- **Replace-on-conflict had to go from the three parent tables.** With enforcement on, an insert that
  replaces an existing row deletes it first, and that delete cascades — re-inserting a Chapter under
  its own id would silently take its subtree. The two leaf tables keep the policy: no children,
  nothing to cascade. No caller is affected; every add mints a fresh uuid and every edit updates.
- **The in-memory fake mirrors the new rule**, refusing a duplicate parent id. The seam's promise is
  that adapters may differ in implementation, not in contract.
- Recorded in [ADR-0006](../../docs/adr/0006-foreign-key-enforcement.md), with the `Migration` entry
  in `CONTEXT.md` extended to say why connection configuration is not a Migration.

## Testing Decisions

A good test here asserts what a DM would observe — what survives a delete, what a write is allowed
to do — not which pragma was executed.

- **Through the app's own open function**, against a real ffi database: enforcement is on; each of
  the three delete levels cascades; each of the three orphan inserts is rejected; a Campaign owning
  nothing still deletes. This is the suite's second file to open a real database, after the
  migration execution test ADR-0005 introduced as a deliberate exception. The justification is not
  weaker for being reused: connection configuration has no pure-Dart surface, since the fake has no
  connection to configure.
- **A characterization test** pinning the destructive behaviour of replace-on-conflict, so
  reintroducing it on a parent table is a visible choice rather than an accident.
- **The v3 → v4 sweep**, seeded the only way orphans could ever have been written — enforcement off
  — then enforcement on before applying the step, reproducing the real upgrade's ordering. Orphans
  go, a healthy subtree stays, a subtree orphaned at its root goes whole, and the step is a no-op
  with nothing to sweep.
- **The reopen test** proving the pragma is per-connection, which is why a migration step was the
  wrong home. It stays in the suite as the reason not to move it there later.
- **Against the fake**: a duplicate parent id is refused, a fresh one accepted. The exception type is
  deliberately not asserted — that would pin a test to which adapter it runs against.

## Out of Scope

- **`onDowngrade`** — still undefined. Unrelated to enforcement; the configure hook is now the
  obvious home for any further pragma.
- **`PRAGMA foreign_key_check` at startup** — it reports a condition this work removes, and no
  player or DM could act on the report.
- **Any other pragma** (journal mode, synchronous) — no defect motivates one.
- **Making the adapter's own path injectable.** It would let `insertChapter`'s conflict policy be
  asserted on the method rather than one layer below it in SQL, and would open every CRUD method to
  real-database testing. A real gap, named in ADR-0006, deliberately not taken here.
- **Catching the new throw in callers.** No caller can produce a duplicate id today; a catch would
  be handling an impossible case.

## Further Notes

- The requested schema version moved 3 → 4, which meant editing by hand a literal that is still
  duplicated outside the ladder. `.scratch/data-transfer/issues/01` removes that duplication and is
  now better motivated, not obsolete.
- ADR numbering: this work took 0006, so the `data-transfer` work references ADR-0007.
