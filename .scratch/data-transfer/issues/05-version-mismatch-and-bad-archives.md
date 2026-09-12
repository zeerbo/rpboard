# 05 — Installations on different versions, and unusable archives

**What to build:** a user who has updated one machine but not the other can still transfer, and a
damaged or unrelated file can no longer cause a confusing failure.

Ticket 02 shipped the strict rule — schema version equal, or refuse — which is safe but forces the
user to update both installations before transferring anything. This ticket relaxes it in the one
direction that can be done without losing data, and makes every refusal legible.

Parent spec: `.scratch/data-transfer/PRD.md`.

**Blocked by:** 02 — Tracer bullet: transfer Characters between installations.

**Status:** ready-for-agent

### Behaviour

- [ ] An archive whose schema version is **lower** than this installation's imports successfully;
      fields the older archive does not carry take the defaults the models already apply
- [ ] An archive whose schema version is **higher** is refused, with a message telling the user to
      update this installation. It is never partially applied — importing it would mean silently
      discarding fields the archive contains, which is data loss dressed as a feature
- [ ] A refused archive is visibly distinguishable in the archive list, so the user sees why it
      cannot be used before selecting it
- [ ] A file that is not JSON is refused with a readable error
- [ ] A file that is JSON but not an RPBoard archive is refused with a readable error
- [ ] An archive with a missing, non-numeric or otherwise unreadable version field is refused
- [ ] A truncated archive is refused
- [ ] Every refusal leaves the database completely untouched, and no backup is consumed for an
      import that never began
- [ ] The format version is checked as well as the schema version, with its own message — the two
      numbers mean different things

### Architecture

- [ ] The compatibility decision is a function of the envelope alone, with no database open, so it
      is testable with no I/O at all
- [ ] Accepting lower schema versions relies on default-tolerance the models already have — this
      is existing behaviour being used, not new leniency being added

### Tests

- [ ] Pure: equal schema version accepted; lower accepted; higher refused. Asserted on the policy
      itself, no database open
- [ ] Pure: an archive from a lower schema version imports and the fields it lacks hold the models'
      documented defaults
- [ ] Pure: not-JSON, JSON-but-not-an-archive, missing version, non-numeric version, and truncated
      payload each produce a distinguishable error
- [ ] Against the in-memory fake: every refusal case leaves the stored state byte-identical to
      before
- [ ] Widget: an archive with a higher schema version surfaces the update-this-installation
      message instead of an import affordance
