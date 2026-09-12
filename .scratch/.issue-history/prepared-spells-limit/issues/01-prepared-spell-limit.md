# 01 — Prepared-spell limit on the Magie tab

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

**Parent spec:** `.scratch/prepared-spells-limit/PRD.md` — read it first; it records every decision and the alternatives that were rejected.

## What to build

A player running a prepared caster can record how many spells they may prepare per day, and the sheet then holds them to it.

On the Magie tab the player types a number labelled **"Incantesimi Preparabili"**, sitting with the spellcasting-ability field above the chip row. A third read-only chip joins CD Magia and Bonus Attacco, labelled **"Preparati"**, reading `<prepared>/<limit>` and updating the moment a spell is toggled. Once the limit is reached the existing prepared toggle refuses the next spell and a snack bar names the limit that was hit, so the inert tap reads as a rule rather than a bug. Un-preparing a spell always works and leaves the spell in the list, so swapping a choice is un-prepare then prepare.

A limit of zero means no limit at all: the chip disappears and the toggle behaves exactly as it does today. That is what makes the feature invisible to classes that know spells without preparing them, and what makes every Character already saved on the device behave after the upgrade exactly as it did before.

Lowering the limit below what is already prepared is accepted as typed. Nothing is un-prepared automatically; the chip turns red, preparing more stays refused, and the player un-prepares whichever spells they choose until they are back within the limit.

Cantrips never count toward the limit and can never be prepared — as is already the case today — and tapping one shows no message.

## Acceptance criteria

### The limit, typed and persisted

- [ ] The Magie tab offers a numeric field labelled "Incantesimi Preparabili", placed with the spellcasting-ability field, above the row of chips.
- [ ] The field is always visible, including when the limit is zero.
- [ ] A negative value cannot be stored: the limit is clamped to zero or above.
- [ ] The limit survives closing and reopening the app.
- [ ] The limit survives navigating away from the Magie tab and back, together with the prepared flags.
- [ ] The limit is carried by the Character's map conversion in both directions; a map with no value for it yields zero.

### Schema

- [ ] A new Migration step is **appended** to the ladder adding an integer column to the characters table, defaulting to 0. No released step is edited.
- [ ] The schema version the SQLite adapter requests is raised to match the new step.
- [ ] A Character saved before the upgrade still exists afterwards with every other field unchanged, and reads a limit of zero.
- [ ] A database created from scratch and a database upgraded into the new version end up with the same schema.
- [ ] The in-memory Database adapter is **not** modified.

### The rule, on Character

- [ ] Character exposes the count of prepared spells, excluding cantrips.
- [ ] Character exposes whether another spell may be prepared.
- [ ] Character exposes a toggle taking a spell's index in its spell list and returning whether the flag was flipped.
- [ ] The toggle refuses — returning false, changing nothing — when the limit is reached and the spell is not currently prepared.
- [ ] The toggle refuses for a cantrip, whatever the limit.
- [ ] Un-preparing is never refused, including from an over-limit state.
- [ ] A limit of zero refuses nothing: any number of spells can be prepared.
- [ ] Lowering the limit below the prepared count leaves every prepared flag untouched, and the over-limit condition is readable from the Character.

### The tab

- [ ] A read-only chip labelled "Preparati", valued `<count>/<limit>`, sits beside CD Magia and Bonus Attacco.
- [ ] That chip is hidden entirely when the limit is zero — the row returns to two chips.
- [ ] That chip renders in the danger colour when the prepared count exceeds the limit, and in the normal accent colour otherwise.
- [ ] The shared chip widget gains an **optional** value-colour parameter defaulting to the accent colour, so the two existing chips are visually unchanged. The widget is not duplicated.
- [ ] A refused prepare attempt shows a snack bar naming the limit, in Italian — e.g. "Limite incantesimi preparati raggiunto (5)".
- [ ] A refused tap on a **cantrip** shows no snack bar.
- [ ] A refused attempt does not mark the Character as changed — there is nothing to persist.
- [ ] Unprepared spell rows look identical whether or not the limit is reached: no dimming, no disabled styling, no restyling of any kind.

### Tests

- [ ] A new group in the Character model test covers: cantrips excluded from the count; refusal at the limit; refusal for a cantrip; un-preparing always allowed; zero meaning no limit; the over-limit state preserving flags; the map round-trip and the missing-key default.
- [ ] A new group in the migration execution test covers the upgrade against a real SQLite database, following the existing armor/equipment upgrade group as its model.
- [ ] No widget-level test is added for the snack bar, the chip colour, or the hidden chip. This is deliberate and recorded in the spec — do not add them in this ticket.
- [ ] The full suite passes.

### Docs

- [ ] The Character entry in CONTEXT.md has the prepared-spell limit added to its list of derived rules that live on Character.
- [ ] No ADR is written.

## Out of scope

Everything the spec lists as out of scope, in particular: no separate "prepared spells" section, no "Prepara" button, no substitution flow, no derivation of the limit from class or level, no long-rest action clearing prepared flags, no per-level limits, no always-prepared spells, and no change to the spell-slot rows, the spell-editing dialog, or the spell list's add/delete behavior.
