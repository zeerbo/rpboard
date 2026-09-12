# 01 — Foreign keys are not enforced: deleting a Campaign leaves orphans

**What to build:** deleting a Campaign removes the Chapters, SessionScreens and SessionComponents it
owns, and a child row can no longer be written referencing a parent that does not exist. Today
neither holds.

The schema declares `ON DELETE CASCADE` on the three child tables, but no `PRAGMA foreign_keys`
statement exists anywhere in the app's source, and SQLite disables foreign key enforcement by
default per connection.

**Blocked by:** None — can start immediately. Independent of the `data-transfer` work.

**Status:** done

### Evidence

A probe run against the production migration ladder on `sqflite_common_ffi` (schema 0→3), since
removed, produced:

```
PRAGMA foreign_keys => [{foreign_keys: 0}]
AFTER DELETE campaign -> chapters=1 screens=1 components=1
ORPHAN INSERT: accepted (FK not enforced)
```

So on that connection: the pragma defaults to off, deleting a Campaign leaves all three descendant
rows behind, and inserting a Chapter whose `campaign_id` does not exist is accepted. The third
result is the more serious one — referential integrity is not enforced at all, not merely the
cascade.

**Stated as a deduction, not a verified fact:** the app behaves the same way. The probe opened its
connection differently from the app's own open path, so this was not executed against the app
directly. The reasoning is that the pragma is a per-connection setting and it appears nowhere in
the source. **Confirm this against the app's real open path as the first step of this ticket**,
before changing anything.

### Why this is not part of the data-transfer work

Enabling enforcement changes deletion semantics across the whole app, and a change of semantics
must not travel hidden inside a feature about moving data between installations. The
`data-transfer` tickets are written so they do not depend on the cascade either way: import deletes
every table explicitly.

### Acceptance criteria

- [x] First: reproduce the behaviour against the app's own database open path, so the deduction
      above becomes a verified fact or is corrected
- [x] Foreign key enforcement is enabled on every connection the app opens, including the one used
      by tests that open a real database
- [x] Deleting a Campaign removes its Chapters, SessionScreens and SessionComponents
- [x] Deleting a Chapter removes its SessionScreens and their SessionComponents
- [x] Deleting a SessionScreen removes its SessionComponents
- [x] Inserting a child row with a non-existent parent id is rejected
- [x] Existing orphan rows on already-installed databases are dealt with deliberately, and the
      choice is written down: either a migration step deletes them, or they are left and the
      reason is recorded. Enabling enforcement does not retroactively validate existing rows, so
      this must be an explicit decision rather than an oversight
- [x] Every existing test still passes — in particular the atomic reorder tests (ADR-0003) and the
      migration execution test (ADR-0005), which now run with enforcement on
- [x] Whether the pragma belongs in a migration step or in the connection open path is decided and
      justified. It is per-connection state, not schema, so a migration step would not survive
      reopening — check this rather than assuming it

## Comments

### Verification closed the deduction

The ticket flagged one claim as a deduction: that the app behaves like the probe, because the
pragma appears nowhere in the source and is per-connection. **Now a verified fact.** The app's open
configuration was extracted into `openAppDatabase(path)` — version, hooks and configuration in one
place, with `SqfliteDatabase` resolving the on-device path and calling it — and the first run of
`foreign_keys_test.dart` against that function failed 7 of 9 tests: `PRAGMA foreign_keys` read `0`,
a Campaign's descendants survived its deletion at all three levels, and every orphan insert was
accepted. Nothing about the app was assumed.

### Where the pragma goes, also verified rather than argued

The ticket asked whether a migration step or the open path was right, and said to check rather
than assume. Checked two ways:

- `sqflite_common` 2.5.11 source: `sqlite_api.dart` documents the hook order as `onConfigure` →
  `onCreate`/`onUpgrade`/`onDowngrade` → `onOpen`, and names enabling foreign keys as the use case;
  `database_mixin.dart` invokes `onConfigure` before the version check and outside the
  version-change transaction — which matters, since SQLite treats the pragma as a no-op inside a
  transaction.
- A test asserts that a database whose pragma was set, then closed and reopened, reads `0` again.
  So a migration step would have protected exactly one launch. That test stays in the suite as the
  reason the next person should not move the pragma into the ladder.

### Existing orphans: deleted, via migration step 4

The choice the ticket demanded. Step 4 deletes Chapters with no Campaign, then SessionScreens with
no Chapter, then SessionComponents with no SessionScreen — that order, not relying on the cascade
it exists to make honest, and `NOT EXISTS` rather than `NOT IN` because `NOT IN` returns nothing at
all if a parent id is NULL, which SQLite permits in a TEXT PRIMARY KEY. No orphan was ever
reachable from the app: every read descends from a parent id, so nothing a DM could see is removed.
Reasoning recorded in ADR-0006 and beside the step itself.

### On "including the one used by tests that open a real database"

Tests that assert the app's behaviour now go through `openAppDatabase`, so they run configured
exactly as production is. Two places deliberately open an unconfigured connection, and neither is
a gap:

- the orphan-sweep tests seed orphan rows the only way they could ever have been written — with
  enforcement off — then turn it on before applying the step, reproducing the real upgrade's order
- `migrations_execution_test.dart` drives a fake ladder over its own `items`/`tags` tables and is
  documented as never touching `productionLadder`; it declares no foreign keys, so there is nothing
  for enforcement to affect

### A regression this change armed, found and disarmed

Not in the ticket, found while checking what enforcement would break. `INSERT OR REPLACE`
resolves a primary key conflict by deleting the existing row first, and with enforcement on that
delete cascades. Probed: re-inserting a Chapter under its own id left its SessionScreen and
SessionComponent counts at **zero**. Harmless before this change, silent subtree loss after it.

The inserts for `campaigns`, `chapters` and `session_screens` now let a duplicate id throw instead.
No caller is affected — every `add` mints a fresh uuid, every edit goes through `update`.
`characters` and `components` keep the replace policy: no children, nothing to cascade, and
changing them would be an unmotivated behaviour change. A characterization test pins the
destructive behaviour so reintroducing the policy on a parent table cannot happen by accident.

Gap stated plainly: that test asserts at the SQL level, not on `insertChapter` itself, because
`SqfliteDatabase`'s methods resolve their path through `path_provider`, which does not exist in a
`flutter test` process. Making the adapter's path injectable would close it and is not done here.

### Scope notes

- The requested schema version moved 3 → 4, which meant editing by hand the literal that
  `.scratch/data-transfer/issues/01` exists to remove. That ticket is now better motivated, not
  obsolete.
- ADR-0006 was taken by this work, so `data-transfer` ticket 02 was renumbered to reference
  ADR-0007, and both it and the PRD now say the atomicity test will be the suite's *third*
  real-database exception rather than the second.
- Full suite green: 241 tests. `flutter analyze lib/` reports 43 issues, all `info`, all
  pre-existing, none in the touched files.
