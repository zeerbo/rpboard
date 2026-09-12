# 05 — Installations on different versions, and unusable archives

**What to build:** a user who has updated one machine but not the other can still transfer, and a
damaged or unrelated file can no longer cause a confusing failure.

Ticket 02 shipped the strict rule — schema version equal, or refuse — which is safe but forces the
user to update both installations before transferring anything. This ticket relaxes it in the one
direction that can be done without losing data, and makes every refusal legible.

Parent spec: `.scratch/data-transfer/PRD.md`.

**Blocked by:** 02 — Tracer bullet: transfer Characters between installations.

**Status:** done

### Behaviour

- [x] An archive whose schema version is **lower** than this installation's imports successfully;
      fields the older archive does not carry take the defaults the models already apply
- [x] An archive whose schema version is **higher** is refused, with a message telling the user to
      update this installation. It is never partially applied — importing it would mean silently
      discarding fields the archive contains, which is data loss dressed as a feature
- [x] A refused archive is visibly distinguishable in the archive list, so the user sees why it
      cannot be used before selecting it
- [x] A file that is not JSON is refused with a readable error
- [x] A file that is JSON but not an RPBoard archive is refused with a readable error
- [x] An archive with a missing, non-numeric or otherwise unreadable version field is refused
- [x] A truncated archive is refused
- [x] Every refusal leaves the database completely untouched, and no backup is consumed for an
      import that never began
- [x] The format version is checked as well as the schema version, with its own message — the two
      numbers mean different things

### Architecture

- [x] The compatibility decision is a function of the envelope alone, with no database open, so it
      is testable with no I/O at all
- [x] Accepting lower schema versions relies on default-tolerance the models already have — this
      is existing behaviour being used, not new leniency being added

### Tests

- [x] Pure: equal schema version accepted; lower accepted; higher refused. Asserted on the policy
      itself, no database open
- [x] Pure: an archive from a lower schema version imports and the fields it lacks hold the models'
      documented defaults
- [x] Pure: not-JSON, JSON-but-not-an-archive, missing version, non-numeric version, and truncated
      payload each produce a distinguishable error
- [x] Against the in-memory fake: every refusal case leaves the stored state byte-identical to
      before
- [x] Widget: an archive with a higher schema version surfaces the update-this-installation
      message instead of an import affordance

## Comments

Implemented in `e572d2f`, completed in `07e1e97`.

`e572d2f` relaxed the policy asymmetrically (equal and lower schema versions
import, a higher one is refused with the update-this-installation message)
and added the `formatVersion` check with its own message. Accepting a lower
version relies on the default-tolerance the models already have; no new
fallback logic was written. The two assertions that pinned the strict interim
rule were updated, since relaxing that rule is what this ticket is for.

`07e1e97` closed a gap found while auditing this ticket: the transport was
swallowing every decode failure, so a non-JSON file, a truncated archive, an
unreadable version field and a mismatched `formatVersion` all vanished from
the archive list with no message, which is the confusing failure this ticket
exists to remove. `listArchives` now returns archives and refused entries
separately, and the screen renders a refused entry with the codec's own
reason and no import affordance. An undecodable file is still never surfaced
as a usable archive, which is the pre-existing invariant it had to keep.
