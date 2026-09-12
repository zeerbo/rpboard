# 03 — Transfer Master Mode material too

**What to build:** the same export and import a user already has for their Characters now carries
their prepared Master Mode material. A DM exports on one installation and finds, on the other,
every Campaign with its Chapters, its SessionScreens and the SessionComponents on them — in the
order they arranged by dragging, with each SessionComponent still the kind of content it was.

This is also where the mechanical guard against silent data loss lands: the exhaustive coverage
test that turns red when an aggregate is not in the snapshot.

Parent spec: `.scratch/data-transfer/PRD.md`.

**Blocked by:** 02 — Tracer bullet: transfer Characters between installations.

**Status:** ready-for-agent

### Behaviour

- [ ] An archive contains every Campaign with all its owned Chapters, SessionScreens and
      SessionComponents
- [ ] Each SessionComponent's `ComponentData` survives the round trip as the typed payload it was —
      a narrative block comes back a narrative block, an NPC stat block an NPC stat block, and an
      unrecognized kind stays whatever the unknown-kind shape preserves (ADR-0001)
- [ ] The dense, zero-based ordering of Chapters, SessionScreens and SessionComponents is
      identical after the round trip (ADR-0003's invariant holds on the imported state)
- [ ] The import confirmation names Campaign counts alongside the Character counts it already
      shows
- [ ] Importing an archive produced by ticket 02 — Characters only, no Campaign material — still
      works and simply results in no Campaigns

### Known effect, expected and not a defect

- [ ] Orphan rows are not exported and are therefore deleted by the first import. Export reaches
      Chapters only by descending from a Campaign, and orphans exist today because foreign keys
      are not enforced (verified — see the separate `foreign-keys-not-enforced` issue). This is
      recorded in the spec as expected behaviour; the ticket does not try to preserve them

### Tests

- [ ] **Exhaustive aggregate coverage** (pure, no I/O): a snapshot populated with every aggregate —
      Characters, Campaigns, Chapters, SessionScreens, and a SessionComponent of *every*
      `ComponentData` kind — survives export then import against the in-memory fake with nothing
      lost and no field altered. This is the test that makes the standing obligation from ticket 02
      mechanical rather than a matter of discipline: a new table left out of the snapshot turns it
      red
- [ ] Pure: ordering is preserved across the round trip for all three Ordered entities
- [ ] Pure: typed `ComponentData` payloads round-trip per kind
- [ ] Pure: an archive with no Campaign material imports cleanly (backward compatibility with
      ticket 02's archives)
- [ ] Widget: the confirmation shows both Character and Campaign counts
