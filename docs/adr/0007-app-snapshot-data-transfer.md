---
status: accepted
---

# AppSnapshot carries state between installations as a versioned logical archive

RPBoard keeps everything a user owns in one SQLite database on the device it runs on, with no
sync or backend of any kind. A user with RPBoard on two machines had no way to carry their
Characters and Campaigns across except finding the database file by hand and copying it — an
implementation detail, with no warning before it overwrote the destination and no way back if the
wrong direction was copied. We add a **Trasferisci dati** screen and, underneath it, `AppSnapshot`:
a typed Dart object holding the complete application state at an instant, following ADR-0001's
rule for `ComponentData` ("persisted as JSON but manipulated as a typed Dart object, never a raw
map") extended to the whole transfer path. `SnapshotCodec` serializes an `AppSnapshot` to logical
JSON wrapped in a versioned envelope (`formatVersion`, `schemaVersion`, `appVersion`, `exportedAt`,
`deviceLabel`, `payload`), with no I/O of its own. `Database` gains two seam methods —
`exportSnapshot()` and `importSnapshot(AppSnapshot)` — implemented by both adapters, with
`importSnapshot` deleting every table it owns explicitly and re-inserting inside one transaction,
never relying on `ON DELETE CASCADE`. `SyncTransport` is the one layer that touches platform I/O,
with a single adapter, `FolderSyncTransport`, reading and writing a conventional `transfer/` folder
next to the database. This ticket (02, "transfer Characters between installations") cuts that path
through every layer for Characters only; a later ticket adds Campaign material as more fields on
`AppSnapshot`, without reshaping the format.

Import semantics are **replace**, not upsert: the user works on one installation at a time, and a
replace has an invariant they can reason about ("both installations now hold the same state") where
a merge would have conflict rules they would have to keep in their head. Version compatibility is
**asymmetric**, as shipped by ticket 05: an archive's `schemaVersion` equal to or lower than this
installation's imports — the models' own `??` fallbacks, 102 of them on `Character.fromMap` alone,
already tolerate the fields an older archive doesn't carry, so accepting a lower schema relies on
existing behaviour rather than adding new leniency — while a higher `schemaVersion` is refused, with
a message telling the user to update this installation, because importing it would mean silently
discarding data this installation cannot represent. `formatVersion` — the JSON shape `SnapshotCodec`
itself reads, independent of the database schema the payload was produced from — has no such
tolerance: `SnapshotCodec.decode` refuses any archive whose `formatVersion` doesn't match its own,
in either direction, with its own message distinct from a `schemaVersion` refusal, because a codec
that has only ever spoken one shape cannot assume it can parse another. An archive the version
policy would refuse is also marked in the Trasferisci dati screen's archive list itself — not only
in the confirmation the user reaches by tapping it — so the reason is visible before it is selected.

## Considered Options

- **A byte copy of the database file** instead of a logical format — rejected. Three reasons, in
  order of weight: (1) a logical format is readable by any future implementation, including one
  that does not use SQLite, while a binary copy is only meaningful to sqflite; (2) going through
  the `Database` seam makes export and import testable against the in-memory fake with no I/O at
  all, the discipline ADR-0002 established; (3) a schema version carried in the envelope turns a
  mismatch into a readable refusal, whereas a raw database file from a newer schema handed to the
  SQLite adapter would be a downgrade the adapter defines no `onDowngrade` hook for — unspecified
  behaviour by construction. A byte copy is still the right tool for the backup a later ticket
  takes before an import: its whole purpose there is to cover the case where the logical export
  lost something, so it must not share the mechanism it protects against.
- **Per-row merge** with last-write-wins or field-level reconciliation — rejected. It needs
  `updated_at` on Character, Chapter, SessionScreen and SessionComponent, none of which carry one
  today (only Campaign does), and adding it would exist only to decorate a confirmation dialog. A
  merge also demands tombstones, since without one a row deleted on one installation would
  reappear at the next transfer. The user works on one installation at a time; replace has an
  invariant they can reason about, merge has rules they would have to remember.
- **A file-picker dependency on day one** — rejected. `file_selector` (flutter.dev, 1.1.0) has no
  "choose a save location" on Android or iOS, and `file_picker` (12.3.0, third-party, moving fast)
  would be a dependency bought for a platform not being targeted yet. The collaudo target is
  Windows, where a native save dialog is convenience rather than capability: the user still moves
  the file between machines in their file manager either way. The usability cost of a conventional
  folder is paid down in the UI instead — the path is written out in full on the screen. When a
  phone enters the picture, the right answer is likely a share sheet or a local-network transfer,
  not a picker, which is exactly what the `SyncTransport` seam keeps open.
- **A generic `transaction(callback)` primitive on the `Database` seam**, so `importSnapshot`
  could be composed from the existing per-aggregate CRUD methods at the call site — rejected, for
  the same reason ADR-0002 gave and ADR-0003 confirmed: it leaks the transaction concept out past
  the seam and forces `InMemoryDatabase` to simulate rollback semantics it has no natural way to
  express faithfully. Import's atomicity has to live inside the adapter, so the operation has to be
  expressible on the seam directly — two typed methods, not a generic escape hatch.
- **`package_info_plus`** to read the app's own version for the envelope's informational
  `appVersion` field — rejected as a dependency bought for one display-only value. A hand-written
  constant mirroring `pubspec.yaml`'s `version:` field does the same job with no new dependency.

## Consequences

- **The standing obligation, recorded in three places.** Choosing a logical format means every
  future addition to the data model must be added to `AppSnapshot`, or it is silently dropped on
  transfer. This is recorded in `CLAUDE.md` (always in context, impossible to miss), in
  `CONTEXT.md` (required reading before exploring any area, with the "covers every aggregate"
  invariant), and here, under this heading. A snapshot populated with every aggregate surviving
  export → import with nothing lost is the test that makes this mechanical rather than a matter of
  discipline; ticket 02 exercises this for Characters, and a later ticket extends it once Campaign
  material is added.
- **The suite's third documented exception to the pure-test rule.** The bulk of this feature's
  tests are pure Dart with no I/O — the codec round trip, the version policy, export/import against
  `InMemoryDatabase`. But `InMemoryDatabase` has no transaction, so it cannot prove a rollback, and
  atomicity is the entire justification for a destructive, replace-semantics import. One test opens
  a real `sqflite_common_ffi` connection (through `openAppDatabase`, exactly as the app opens its
  own) and forces an import to fail partway through, asserting the database is left exactly as it
  was — no rows deleted, no rows inserted. This follows the migration execution test (ADR-0005) and
  the foreign-key test (ADR-0006) as the third instance of the same reasoning: some risks can only
  be verified against a real, transactional connection.
- **`exportSnapshotFrom`/`importSnapshotInto` are top-level functions in `db.dart`, alongside
  `openAppDatabase`.** `SqfliteDatabase`'s CRUD methods resolve their connection through
  `path_provider`, which has no implementation in a `flutter test` process (a limitation ADR-0006
  already documented). Pulling the transactional core out to functions taking an open connection
  directly is what makes the atomicity test possible without instantiating `SqfliteDatabase` at
  all — the same shape `openAppDatabase` already established for the migration ladder.
- **`importSnapshot` only ever touches the tables `AppSnapshot` currently carries.** Ticket 02
  narrows scope to Characters, so import deletes and repopulates the `characters` table alone; it
  does not touch `campaigns`, `chapters`, `session_screens` or `components`. This is deliberate,
  not partial: a destructive replace of aggregates the archive does not even carry would be data
  loss dressed as a tracer bullet. When Campaign material is added to `AppSnapshot`, the same
  transaction grows to delete and repopulate those tables too — additive to the transaction, not a
  redesign of it.
- **`FolderSyncTransport` takes an injectable document-root resolver rather than mocking
  `path_provider`'s platform channel.** Mirrors `Migrations({this.ladder = productionLadder})`:
  production always resolves the real app documents directory, and a test substitutes a temporary
  one through the same constructor parameter. This avoided a new dev dependency
  (`path_provider_platform_interface`) that a platform-channel mock would have needed.
  `test/core/sync/folder_sync_transport_test.dart` exercises the adapter's realistic failure modes
  — a missing exchange folder on first export, a non-archive file mixed into the folder,
  write-then-read-back, deterministic listing order — against a real, disposable temporary
  directory.
- **Orphan rows are not this feature's problem to fix, and it must not depend on them being
  fixed.** `chapters`, `session_screens` and `components` declare `ON DELETE CASCADE`, but nothing
  in the app ever enabled `PRAGMA foreign_keys` until a separate, already-landed fix
  (`fix(database): enforce foreign keys and sweep orphaned rows`). `importSnapshot` deletes every
  table it owns explicitly regardless, so it is correct whether or not enforcement is on. Once
  Campaign material is exported, orphaned Chapters, SessionScreens and SessionComponents — rows no
  read path has ever surfaced to a DM — are simply not reachable from any Campaign and so are never
  exported; the first import after that sweeps them, which is expected and was verified separately,
  not something this ticket needed to reason about further.
- **Version compatibility shipped in two steps, on purpose.** Ticket 02 shipped a strict interim
  policy — `SchemaVersionPolicy` modeled three outcomes (`accepted`, `refusedNewer`,
  `refusedOlder`), and evaluated `refusedOlder` the same way as `refusedNewer`: anything but an
  exact match was refused. Ticket 05 relaxes that half: `refusedOlder` is gone from the enum
  entirely (`evaluate` only ever returns `accepted` or `refusedNewer` now), and the change to
  `version_policy_test.dart` this required is recorded there and in that ticket's own report,
  rather than being pre-empted here. The same ticket also added the `formatVersion` check
  `SnapshotCodec.decode` had never performed (it read the field's presence and type but never
  compared its value), and the archive-list warning in the Trasferisci dati screen.
- **What makes this reusable on a new platform is the layering, not any single choice.** The
  format (`SnapshotCodec`) and the database work (`Database.exportSnapshot`/`importSnapshot`) are
  platform-agnostic or adapter-local; only `SyncTransport` touches platform I/O, and only it needs
  rewriting for a new platform — a share sheet, a local-network transfer. Nothing above or below it
  changes.
