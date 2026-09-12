# 04 — Safety net: backup before import, and restore

**What to build:** importing the wrong archive stops being unrecoverable. Before an import touches
anything, the app copies the destination's database aside; the **Trasferisci dati** screen lists
those copies and lets the user put one back. A user who imports an old archive by mistake gets
their state back from inside the app, without hunting for files.

Parent spec: `.scratch/data-transfer/PRD.md`.

**Blocked by:** 02 — Tracer bullet: transfer Characters between installations.

**Status:** ready-for-agent

### Behaviour

- [ ] Every import is preceded by a backup of the current database, taken before any row is
      touched
- [ ] The backup is a **byte-for-byte copy of the database file**, not a logical export. This is
      deliberate: the backup's purpose is to cover the case where the logical export lost
      something, and a backup sharing the mechanism it protects against is a copy of the problem
- [ ] Backups are named with an ISO-8601 timestamp and kept in their own folder next to the
      database
- [ ] Only the 5 most recent backups are kept; older ones are removed as new ones are made
- [ ] The screen lists the backups with their timestamps
- [ ] Restore is an explicit user action with its own confirmation. It is **never** automatic on
      error — a rollback triggered by a misread error can destroy more than it saves
- [ ] After a restore, the app shows the restored state without the user having to restart it
- [ ] A failed backup aborts the import rather than proceeding unprotected
- [ ] The screen has a control that opens the exchange folder in the platform's file manager

### Architecture

- [ ] Reading the database file's location stays inside the adapter — the path is private by
      design — so backup, rotation and restore sit at the same level as the database rather than
      above it
- [ ] Restoring a backup taken before an app update means reopening an older schema, which the
      migration ladder already carries forward on open (ADR-0005). Restoring is therefore never a
      downgrade

### Tests

- [ ] Against a temporary directory: a backup is created before import and contains the
      pre-import bytes exactly
- [ ] Against a temporary directory: retention keeps 5 and drops the oldest
- [ ] Against a temporary directory: restore puts back the exact bytes
- [ ] A backup that cannot be written aborts the import, and the database is left untouched
- [ ] Widget: the backup list renders its entries, and restore asks for confirmation before acting
