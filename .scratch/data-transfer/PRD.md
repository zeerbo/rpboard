# Data transfer between installations — AppSnapshot

Status: ready-for-agent

## Problem Statement

RPBoard keeps everything a user owns in one SQLite database on the device it runs on
(`CONTEXT.md`: "Single-user local app (SQLite on device), no sync/multiplayer"). A user who
installs RPBoard on a second machine starts from an empty database: the Characters they built in
PG Mode and the Campaigns, Chapters, SessionScreens and SessionComponents they prepared in Master
Mode do not follow them.

Today the only way to carry that state across is to find the database file by hand, know that it
lives under the application documents directory, and copy it — which requires knowing an
implementation detail, gives no warning before it overwrites the destination, and offers no way
back if the wrong direction is copied.

The user wants to work on either installation and always find their current data there, while
keeping the app what it is: local and stand-alone. No backend service is to be written, and no
external cloud is to be relied on.

## Solution

A **Trasferisci dati** screen that writes the complete application state to a single portable
file, and reads such a file back.

The user exports on the installation they last worked on, moves the one file to the other machine
by whatever means they already use (USB stick, file share, whatever they like — the app does not
care), and imports it there. After the import the destination holds exactly the state the source
had.

Import is destructive by design: it replaces the destination's state rather than merging into it,
because the user works on one installation at a time and a replace has an invariant they can
reason about ("both installations now hold the same state") where a merge would have conflict
rules they would have to keep in their head. To make that safe rather than frightening:

- the app takes a backup of the destination's database before it touches anything, and offers to
  restore it,
- the confirmation names what is about to change, in the only terms the app can honestly
  compute today: how many Characters and Campaigns exist locally versus in the archive,
- an archive produced by a newer version of the app is refused with an explanation, never
  partially applied.

The mechanism is a **file** because a file is the one transport every platform has. It is
deliberately built behind a seam so that a second transport (a phone's share sheet, a
device-to-device transfer over the local network) can be added later without touching the format
or the database.

## User Stories

### Transferring state

1. As a user with RPBoard on two machines, I want to export my whole state to a single file, so
   that I can carry it to the other machine without knowing where the database lives.
2. As a user, I want the export to include every Character, so that my PG Mode sheets survive the
   move.
3. As a user, I want the export to include every Campaign with its Chapters, SessionScreens and
   SessionComponents, so that my prepared Master Mode material survives the move.
4. As a user, I want each SessionComponent's ComponentData to survive the round trip with its
   typed payload intact, so that a narrative block comes back a narrative block and an NPC stat
   block comes back an NPC stat block.
5. As a user, I want the drag-chosen order of Chapters, SessionScreens and SessionComponents to
   survive the round trip, so that my prepared material is in the order I arranged it.
6. As a user, I want to import an archive and find the other installation's state, so that I can
   keep working where I left off.
7. As a user, I want the import to be all-or-nothing, so that a failure halfway through never
   leaves me with half my Campaigns and none of my Characters.
8. As a user, I want export to write a new file each time rather than overwrite the previous one,
   so that an older archive is still there if I need it.

### Understanding what is about to happen

9. As a user, I want the confirmation before an import to tell me how many Characters and
   Campaigns I have locally and how many are in the archive, so that I can notice when I am about
   to import the wrong file.
10. As a user, I want to see when an archive was exported and from which machine, so that I can
    tell two archives apart without opening them.
11. As a user, I want to be told plainly that import replaces my local state, so that the
    destruction is never a surprise.
12. As a user, I want to be able to cancel at the confirmation, so that opening the screen out of
    curiosity costs me nothing.
13. As a user, I want the archives the app can see listed with their metadata, so that I pick one
    from a list rather than typing a path.

### Not losing data

14. As a user, I want the app to back up my database before an import, so that importing the
    wrong archive is recoverable.
15. As a user, I want to restore a backup from inside the app, so that recovery does not require
    me to find files by hand.
16. As a user, I want old backups cleaned up automatically, so that they do not grow without
    bound.
17. As a user, I want restoring a backup to be something I ask for explicitly, so that the app
    never silently rolls my data back on an error it misread.

### Version mismatch between installations

18. As a user whose two installations are on different app versions, I want an archive from the
    older one to import successfully, so that I am not forced to update both machines before I
    can transfer.
19. As a user, I want an archive from a *newer* installation to be refused with a message telling
    me to update this installation, so that I never silently lose the data the newer version
    knows about and this one does not.
20. As a user, I want a corrupt or truncated archive to be refused with a readable error, so that
    a bad file cannot damage my database.
21. As a user, I want a file that is not an RPBoard archive at all to be refused, so that picking
    the wrong file is harmless.

### Finding the file

22. As a user, I want to see the exchange folder's location written out in the screen, so that I
    know where to look for what I exported.
23. As a user, I want a button that opens that folder, so that moving the file to the other
    machine is one click plus a drag.
24. As a user, I want the screen to work when the exchange folder does not exist yet, so that a
    fresh install's first export just works.

### Keeping the vocabulary and the shape of the app

25. As a user, I want data transfer to be reachable from the home screen without being presented
    as a third mode of the app, so that "Modalità Giocatore" and "Modalità Master" stay the two
    things RPBoard is.
26. As a user, I want the feature labelled "Trasferisci dati" rather than "Sincronizza", so that
    its name does not promise an automatic two-way sync it does not perform.

### Keeping it correct as the app grows

27. As a developer or agent adding a field to the data model, I want the obligation to extend the
    snapshot to be stated where I cannot miss it, so that I learn about it before I write the
    code rather than after a red test.
28. As a developer or agent, I want a test that fails when an aggregate is not covered by the
    snapshot, so that a forgotten table is caught mechanically and not by discipline alone.
29. As a developer, I want the snapshot's format version and the database schema version to be
    separate numbers, so that changing the exchange format and changing the schema are
    independent events.
30. As a developer targeting a new platform later, I want only the transport layer to need
    rewriting, so that the format and the database work carry over unchanged.

## Implementation Decisions

### The snapshot is a typed Dart object, not a map

`AppSnapshot` is the complete application state at an instant: every Character, and every
Campaign with its owned Chapters, SessionScreens and SessionComponents. It holds the existing
typed domain models, including typed `ComponentData` — never raw JSON maps. This follows
ADR-0001's rule for `ComponentData` ("Persisted as JSON but manipulated as a typed Dart object,
never a raw map") and extends it to the transfer path.

`AppSnapshot` is pure data with no I/O. Serialization lives above it.

### Export and import are two new methods on the existing `Database` seam

`Database` gains `exportSnapshot()` and `importSnapshot(AppSnapshot)`. Both adapters implement
them: the SQLite adapter and the test-owned in-memory fake described in ADR-0002.

This is a deliberate extension of the existing seam rather than a new one, for a reason that is
not stylistic: **import must be atomic**, and the seam keeps lifecycle and transactions private
inside the adapter by design. A caller-side composition of the existing per-aggregate CRUD
methods cannot roll back, and the operation being composed deletes everything the user owns. The
only place atomicity can live is inside the adapter, so the operation has to be expressible on
the seam.

`importSnapshot` deletes every row of every table explicitly and then inserts, inside a single
transaction. It does **not** rely on `ON DELETE CASCADE`: see "Orphan rows" below.

Import semantics are **replace**, not upsert. No merge, no per-row conflict resolution, no
tombstones — the user works on one installation at a time (see Out of Scope).

### The exchange format is logical JSON with a versioned envelope

Not a byte copy of the database file. Three reasons, in order of weight:

1. A logical format is readable by any future implementation, including one that does not use
   SQLite. A binary copy is only meaningful to sqflite, which contradicts the requirement that
   the mechanism survive a platform change.
2. Going through the `Database` seam makes export and import testable against the in-memory fake
   with no I/O at all, which is the discipline ADR-0002 established.
3. A schema version carried in the envelope turns a mismatch into a readable refusal. A raw
   database file from a newer schema handed to the SQLite adapter would be a downgrade, and the
   adapter defines no `onDowngrade` hook — the behaviour is unspecified by construction.

The envelope carries:

| Field | Meaning |
| --- | --- |
| `formatVersion` | version of the exchange format itself, independent of the database schema |
| `schemaVersion` | database schema version the payload was produced from |
| `appVersion` | app version string, informational |
| `exportedAt` | ISO-8601 timestamp |
| `deviceLabel` | which installation produced it |
| `payload` | the serialized `AppSnapshot` |

`deviceLabel` comes from the platform's host name. It is a label, not domain data, so it is not
persisted in the database and no settings table is introduced for it. The host name is only
available through `dart:io`, so the web target needs the same `kIsWeb` guard the SQLite adapter
already applies before initialising ffi.

`formatVersion` and `schemaVersion` are separate because the JSON shape and the database schema
can change independently, for different reasons.

### Version compatibility is asymmetric: accept older, refuse newer

- `schemaVersion` equal to this installation's: import.
- `schemaVersion` lower: import. Fields the older archive does not carry take the defaults the
  models already apply — `Character.fromMap` alone contains 102 `??` fallbacks, so
  default-tolerance on missing keys is a property the code already has, not one to be added.
- `schemaVersion` higher: refuse, with a message telling the user to update this installation.
  Importing it would mean silently discarding fields that exist in the archive, which is data
  loss dressed as a feature.

### One source of truth for the schema version

The current schema version exists today as a literal in the SQLite adapter's open call *and* as
the last step of the production migration ladder. The codec needs it, which makes two copies of
one number a latent divergence. The ladder's last step becomes the single source, and the adapter
reads it from there instead of repeating the literal. This is a small correction carried by this
work, not a behaviour change: the value is the same.

### Transport is a seam with exactly one adapter today

`SyncTransport` is the only layer that touches platform I/O. Its single adapter writes to and
reads from a conventional folder inside the app's own data directory: `transfer/` next to the
database, with export files named `rpboard-transfer-<ISO8601>.json` and never overwritten.

No file-picker dependency is added. The verified reason: `file_selector` (flutter.dev, 1.1.0) has
no "choose a save location" on Android or iOS, and `file_picker` (12.3.0, third-party, moving
fast) would be a dependency bought for a platform that is not being targeted yet. The collaudo
target is Windows, where a native save dialog is convenience rather than capability — the user
still moves the file between machines in their file manager either way. When a phone enters the
picture, the right answer is likely a share sheet or a local-network transfer, not a picker, and
the seam is what keeps that option open.

The usability cost of a conventional folder — a folder the user cannot find — is paid down in the
UI: the path is written out in full on the screen, with a button that opens it.

### Backups are byte copies of the database file

Before an import, the destination's database file is copied, byte for byte, to a `backups/`
folder next to it, named `rpboard-backup-<ISO8601>.db`, with a retention of the 5 most recent.

Byte copy and not a logical export, deliberately: the backup's whole purpose is to cover the case
where the logical export lost something. A backup that shares the mechanism it protects against
is a copy of the problem.

Restore is an explicit user action from the screen. It is never automatic on error — a rollback
triggered by a misread error can destroy more than it saves.

Reading the database file's path requires a third adapter-level capability, since the path is
private to the adapter; backup, rotation and restore therefore live at the same level as the
database, not above it.

### The confirmation says only what the app can honestly compute

The confirmation compares **counts** — Characters and Campaigns, local versus archive — plus the
archive's `exportedAt` and `deviceLabel` from the envelope.

It does **not** claim which state is "more recent". That is not computable: `created_at` and
`updated_at` exist on Campaign only; Character, Chapter, SessionScreen and SessionComponent carry
no timestamps. Adding them to every table would be a schema change and the foundation of the
per-row merge that is explicitly out of scope — bought to decorate a dialog. A count that goes
down is the most legible warning available, and it is honest.

### The screen is a route, not a third mode

`Trasferisci dati` is its own route, reached from an icon control on the home screen. It is not a
third mode card: `CONTEXT.md` defines PG Mode and Master Mode as the two faces of the app, and
data transfer is a utility, not a way to play.

The screen shows: the exchange folder path with an "open folder" control, an export action, the
list of archives found with their envelope metadata, an import action leading to the
confirmation, and the list of backups with a restore action.

The domain identifier is `AppSnapshot`; the user-facing label is "Trasferisci dati". The two are
allowed to differ, exactly as `SessionScreen` is labelled "Scena" in Master Mode. "Sincronizza"
is rejected as a label: it promises automatic, two-way behaviour this mechanism does not perform.

### Orphan rows: a verified pre-existing defect this work must not depend on

The schema declares `ON DELETE CASCADE` on `chapters`, `session_screens` and `components`, but no
`PRAGMA foreign_keys` statement exists anywhere in the app's source. A probe run against the
production migration ladder on `sqflite_common_ffi` (schema 0→3) produced:

```
PRAGMA foreign_keys => [{foreign_keys: 0}]
AFTER DELETE campaign -> chapters=1 screens=1 components=1
ORPHAN INSERT: accepted (FK not enforced)
```

So foreign keys are not enforced on that connection: deleting a Campaign leaves its Chapters,
SessionScreens and SessionComponents behind, and a Chapter referencing a non-existent Campaign is
accepted. *Deduction, stated as such:* the app behaves the same way, because the PRAGMA appears
nowhere in the source and it is a per-connection setting — this was not executed against the
app's own open path.

Two consequences for this work:

1. `importSnapshot` deletes every table explicitly and never relies on the cascade, so it is
   correct whether or not the defect is fixed.
2. Export reaches Chapters only by descending from a Campaign, so **orphan rows are not exported,
   and the first import deletes them.** This is expected behaviour, recorded here so it is not
   discovered as a surprise.

Fixing the PRAGMA is tracked separately: enabling it changes deletion semantics across the whole
app, which must not travel hidden inside a data-transfer feature.

### The standing obligation, recorded in three places

Choosing a logical format means every future addition to the data model must be added to the
snapshot, or it is silently dropped on transfer. This cost was accepted explicitly. It is
recorded in three places with distinct, non-redundant roles:

| Where | What it says | Why there |
| --- | --- | --- |
| Project instructions (`CLAUDE.md`) | one line: touching the data model means updating `AppSnapshot` and its round-trip test | always in context; impossible to miss |
| Domain glossary (`CONTEXT.md`) | `AppSnapshot` and `Trasferisci dati` entries, with the "covers every aggregate" invariant | required reading before exploring any area |
| `docs/adr/0007-*` | the decision, the rejected alternatives, and this cost under Consequences | where the trade-offs are kept |

The ADR is written together with the first implementation issue, not ahead of it: this repo
records decisions when they are resolved, not as up-front planning.

### Layering

| Layer | Responsibility | Platform-specific |
| --- | --- | --- |
| `SyncTransport` (file adapter) | deliver and receive bytes | **yes** |
| `SnapshotCodec` | `AppSnapshot` ↔ JSON, envelope, version policy | no |
| `Database.exportSnapshot` / `importSnapshot` | read and replace state, atomically | inside the adapter |

Only the top layer is rewritten for a new platform.

## Testing Decisions

A good test here asserts externally observable behaviour: what a round trip preserves, what an
import leaves in the database, what a refused archive leaves unchanged, what the confirmation
tells the user. None of them reach for private state or assert on the shape of intermediate
calls.

### Pure tests, no I/O — the bulk of the suite

Prior art: `test/core/ordering/reorder_test.dart`, `test/models/component_test.dart`, the
`test/providers/*_test.dart` family, and `Migrations.stepsFrom`'s selection tests — all pure Dart
against the in-memory fake or pure functions.

- **Codec round trip.** An `AppSnapshot` serialized and read back equals the original, including
  typed `ComponentData` payloads and the order of every Ordered collection.
- **Exhaustive aggregate coverage.** A snapshot populated with *every* aggregate — Characters,
  Campaigns, Chapters, SessionScreens, SessionComponents of every `ComponentData` kind — survives
  export → import against the in-memory fake with nothing lost. This is the test that makes the
  standing obligation mechanical: a new table not added to the snapshot turns it red.
- **Version policy.** Equal `schemaVersion` imports; lower imports and fills absent fields with
  model defaults; higher is refused. Asserted on the policy itself, with no database open.
- **Malformed envelopes.** Not JSON, JSON but not an envelope, envelope with a missing or
  non-numeric version, truncated payload — each refused with a distinguishable error and no
  partial application.
- **Replace semantics.** Importing into a fake holding different data leaves exactly the
  archive's content, with nothing of the previous state surviving.

### One test against real SQLite — atomicity

Prior art and precedent: `test/core/database/migrations_execution_test.dart`, the repo's first
test to open a real database. ADR-0005 justified that exception in terms that apply verbatim
here: step selection was the easy half, and "skipping an execution test would leave exactly that
risk unverified".

The in-memory fake replaces maps; it has no transaction, so it cannot prove a rollback. Since the
whole justification for a destructive import is that it is atomic, atomicity is asserted where it
actually lives: an import forced to fail partway against a real ffi database leaves the database
exactly as it was — no rows deleted, no rows inserted.

This is the suite's **third** documented exception to the pure-test rule, and the ADR records it
as such.

### Transport tests against a temporary directory

The realistic failure is not a codec bug; it is a missing folder, a truncated file, a file that is
not an archive. Exercised against a temporary directory: write then read back; a missing exchange
folder on first export; archives listed in a deterministic order with their envelope metadata;
backup creation; retention dropping the oldest beyond 5; restore putting back the exact bytes.

### Widget tests for the confirmation

Prior art: `test/screens/pg/character_sheet_screen_test.dart`,
`test/screens/master/session/components/component_view_test.dart`.

The confirmation is the last thing between the user and losing their data, so it is tested rather
than treated as chrome:

- the confirmation shows the local and archive counts for Characters and Campaigns
- it shows the archive's `exportedAt` and `deviceLabel`
- cancelling changes nothing
- import is unavailable when no archive is present
- an archive with a higher `schemaVersion` surfaces the update-this-installation message rather
  than an import affordance

## Out of Scope

- **Per-row merge.** No `updated_at` on the remaining tables, no last-write-wins, no field-level
  reconciliation. The user works on one installation at a time; a replace has an invariant they
  can reason about and a merge has rules they would have to remember.
- **Tombstones.** Without a merge there is nothing for them to disambiguate. (With one they would
  be mandatory: otherwise a row deleted on one installation reappears at the next transfer.)
- **Timestamps on Character, Chapter, SessionScreen, SessionComponent.** They are the foundation
  of the merge above, and their only benefit here would be a nicer confirmation dialog.
- **Selective export** of a single Character or a single Campaign subtree. The envelope holds a
  list of root aggregates rather than a shape that assumes "everything", so adding this later is
  filtering that list, not redesigning the format — but selective export forces an upsert
  semantics and therefore a conflict rule on id collision, which is the merge question again.
- **Any transport other than the conventional folder** — no local-network transfer, no share
  sheet, no QR, no file-picker dependency. The seam is the deliverable here; further adapters are
  not.
- **Automatic or scheduled transfer.** Export and import are both explicit user actions.
- **Any backend service or external cloud storage.** The stated constraint on this work.
- **Bundling image assets.** Verified as unnecessary: the image SessionComponent renders through
  `Image.asset` with a hand-typed path, so images ship inside the app binary; there are no
  user-supplied files anywhere in the app. The entire user state is the one database file.
- **Enabling `PRAGMA foreign_keys`.** Verified defect, tracked in its own issue; it changes
  deletion semantics app-wide.
- **Multi-user or multiplayer anything.** Unchanged from `CONTEXT.md`.

## Further Notes

- **Collaudo without a second machine.** The whole round trip is exercisable on one Windows
  machine by pointing two runs at different data directories, so none of this needs a second
  device to verify.
- **Delivery is four issues**, in a chain of real dependencies: (01) `AppSnapshot` + codec +
  envelope + version policy, pure, touching nothing; (02) the two seam methods on both adapters,
  with the atomicity and coverage tests; (03) `SyncTransport` with the folder adapter, plus
  backup, rotation and restore; (04) the "Trasferisci dati" screen, its route and its widget
  tests. The first genuinely useful state arrives at the end of 03 — from there data transfers,
  and the screen is convenience.
- **Accepted risks**, all with a named mitigation: import destroys local state (byte backup plus
  a count-bearing confirmation); a new table left out of the snapshot loses data (exhaustive
  coverage test plus the three documentation touchpoints); the exchange folder is hard to find
  (path shown in full, with an open-folder control); the first import cleans up orphan rows left
  by the foreign-key defect (expected, recorded above).
- **What makes this reusable on a new platform** is the layering, not any single choice: the
  format and the database work are platform-agnostic and pure or adapter-local, and the only
  thing a new platform needs is another `SyncTransport`.
