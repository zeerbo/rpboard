# 02 — Tracer bullet: transfer Characters between installations

**What to build:** the first complete, demoable path. A user with RPBoard on two machines opens
**Trasferisci dati** from the home screen, exports, finds one file in the exchange folder, moves it
to the other machine however they like, imports it there with a confirmation, and their Characters
are on the second installation.

Scope is deliberately narrowed to Characters — Campaign material comes in ticket 03 — but the path
is cut through **every** layer, because a slice that stops short of the screen cannot be
demonstrated. This ticket therefore carries the scaffolding all later tickets build on: the
snapshot, the exchange format, the two seam methods, the transport seam and its one adapter, the
route and the screen.

Parent spec: `.scratch/data-transfer/PRD.md`.

**Blocked by:** 01 — One source of truth for the schema version.

**Status:** ready-for-agent

### Behaviour

- [ ] An icon control on the home screen opens the **Trasferisci dati** screen — **not** a third
      mode card: PG Mode and Master Mode stay the two faces of the app (`CONTEXT.md`)
- [ ] The screen shows the exchange folder's full path in readable form
- [ ] Export writes one archive file containing every Character, named with an ISO-8601 timestamp,
      never overwriting a previous archive
- [ ] The screen lists the archives it can see, each showing when it was exported and from which
      installation
- [ ] Choosing an archive shows a confirmation that states plainly that import **replaces** local
      state, and names the Character count locally versus in the archive
- [ ] Cancelling the confirmation changes nothing
- [ ] Confirming replaces the local Characters with the archive's, all-or-nothing
- [ ] Export works on a fresh install where the exchange folder does not exist yet

### Architecture

- [ ] `AppSnapshot` holds typed domain models, never raw maps — extending ADR-0001's rule to the
      transfer path
- [ ] The archive is logical JSON wrapped in an envelope carrying: format version (of the exchange
      format), schema version, app version, export timestamp, and a device label taken from the
      platform host name, guarded for the web target the way the SQLite adapter already guards its
      ffi initialisation
- [ ] Format version and schema version are separate numbers — the JSON shape and the database
      schema change for different reasons
- [ ] The `Database` seam gains export and import of an `AppSnapshot`; **both** adapters implement
      them, the SQLite one and the test-owned in-memory fake (ADR-0002)
- [ ] Import is atomic inside the adapter: one transaction, explicit deletes of every table it
      owns followed by inserts. It does **not** rely on `ON DELETE CASCADE` — see the separate
      `foreign-keys-not-enforced` issue for why that would be unsafe
- [ ] Import semantics are replace, not upsert
- [ ] A `SyncTransport` seam isolates all platform I/O; its single adapter reads and writes a
      conventional folder inside the app's own data directory. **No file-picker dependency is
      added**
- [ ] Version policy in this ticket is strict: schema version equal, or the archive is refused.
      Ticket 05 relaxes it
- [ ] The three layers stay separate: transport does I/O, the codec does format with no I/O, the
      seam does state

### Documentation

- [ ] `docs/adr/0007-*` records the decision, the rejected alternatives (byte copy of the database
      file, per-row merge, a file-picker dependency on day one) and, under Consequences, the
      standing cost accepted with the logical format
- [ ] `CONTEXT.md` gains `AppSnapshot` and `Trasferisci dati` entries, each with its `Avoid` list;
      "Sincronizza" is named as avoided, because it promises automatic two-way behaviour this
      mechanism does not perform
- [ ] `CLAUDE.md` gains one line: touching the data model means extending `AppSnapshot` and its
      round-trip test
- [ ] `CONTEXT.md`'s decisions table gains a row for this work

### Tests

- [ ] Pure, no I/O: a snapshot serialized and read back equals the original
- [ ] Pure, no I/O: export then import against the in-memory fake preserves every Character field
- [ ] Pure, no I/O: importing into a fake holding different Characters leaves exactly the
      archive's content — nothing of the previous state survives
- [ ] Against a real ffi database: an import forced to fail partway leaves the database exactly as
      it was. This is the suite's **third** documented exception to the pure-test rule, after the
      migration execution test and the foreign key test (ADR-0006); ADR-0005's reasoning applies verbatim — the in-memory fake has no
      transaction, so it cannot prove a rollback, and atomicity is the entire justification for a
      destructive import
- [ ] Against a temporary directory: write then read back; first export with no exchange folder
      present; archives listed with their envelope metadata in a deterministic order
- [ ] Widget: the confirmation shows local and archive Character counts, shows the archive's export
      timestamp and device label, cancelling changes nothing, and import is unavailable with no
      archive present
