# 01 — One source of truth for the schema version

**What to build:** nothing changes for the user. The current schema version exists twice — as a
literal in the SQLite adapter's open call, and as the version of the last step of the production
migration ladder. The adapter stops repeating the literal and derives the version from the ladder
instead.

This is a prefactor. Ticket 02 needs the schema version in a third place (the archive envelope),
and three copies of one number is a divergence waiting to happen: a future migration step appended
without touching the adapter would leave the ladder ahead of the version the adapter requests, and
the new step would never run.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] The SQLite adapter requests the version derived from the production ladder's last step, not a
      hand-written number
- [ ] The value requested is unchanged from what ships today, so every existing install is
      untouched — this is behaviour-preserving
- [ ] A test asserts the adapter's requested version equals the ladder's last step's version, so
      appending a step without updating anything else cannot silently skip it
- [ ] The existing migration tests still pass unchanged
- [ ] `Migrations` stays below the `Database` seam and the seam's interface is untouched
      (ADR-0002, ADR-0005)
