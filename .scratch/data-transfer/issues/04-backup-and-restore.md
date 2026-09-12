# 04 — Safety net: backup before import, and restore

**What to build:** importing the wrong archive stops being unrecoverable. Before an import touches
anything, the app copies the destination's database aside; the **Trasferisci dati** screen lists
those copies and lets the user put one back. A user who imports an old archive by mistake gets
their state back from inside the app, without hunting for files.

Parent spec: `.scratch/data-transfer/PRD.md`.

**Blocked by:** 02 — Tracer bullet: transfer Characters between installations.

**Status:** done

### Behaviour

- [x] Every import is preceded by a backup of the current database, taken before any row is
      touched
- [x] The backup is a **byte-for-byte copy of the database file**, not a logical export. This is
      deliberate: the backup's purpose is to cover the case where the logical export lost
      something, and a backup sharing the mechanism it protects against is a copy of the problem
- [x] Backups are named with an ISO-8601 timestamp and kept in their own folder next to the
      database
- [x] Only the 5 most recent backups are kept; older ones are removed as new ones are made
- [x] The screen lists the backups with their timestamps
- [x] Restore is an explicit user action with its own confirmation. It is **never** automatic on
      error — a rollback triggered by a misread error can destroy more than it saves
- [x] After a restore, the app shows the restored state without the user having to restart it
- [x] A failed backup aborts the import rather than proceeding unprotected
- [x] The screen has a control that opens the exchange folder in the platform's file manager

### Architecture

- [x] Reading the database file's location stays inside the adapter — the path is private by
      design — so backup, rotation and restore sit at the same level as the database rather than
      above it
- [x] Restoring a backup taken before an app update means reopening an older schema, which the
      migration ladder already carries forward on open (ADR-0005). Restoring is therefore never a
      downgrade

### Tests

- [x] Against a temporary directory: a backup is created before import and contains the
      pre-import bytes exactly
- [x] Against a temporary directory: retention keeps 5 and drops the oldest
- [x] Against a temporary directory: restore puts back the exact bytes
- [x] A backup that cannot be written aborts the import, and the database is left untouched
- [x] Widget: the backup list renders its entries, and restore asks for confirmation before acting

## Comments

Implemented in `5f1b782`, merged in `26c25f8`. Every import is preceded by a
byte-for-byte copy of the database file into its own folder, named with an
ISO-8601 timestamp and rotated to the 5 most recent; a backup that cannot be
written aborts the import rather than proceeding unprotected. Restore is an
explicit action with its own confirmation and is never triggered on error.

Verified against a temporary directory (exact bytes, retention, restore) and
against a real ffi connection for the close-copy-reopen sequence, so the
"no restart needed" criterion rests on a test rather than on the provider
invalidation alone.

The merge in `26c25f8` also extended `restoreBackup` to refresh the Campaign,
Chapter, SessionScreen and SessionComponent lists, not just the Character
roster: a restore replaces the whole database file, so leaving Master Mode
material on a stale list would have shown pre-restore Campaigns afterwards.
