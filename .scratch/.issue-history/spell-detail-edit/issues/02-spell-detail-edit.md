# 02 — A spell row opens for consulting and editing

**Blocked by:** 01 — A real tap target for the prepared toggle.

**Status:** done

**Parent spec:** `.scratch/spell-detail-edit/PRD.md` — read it first; it records every decision and the alternatives that were rejected.

## What to build

A player can reopen a spell they have already entered, read everything it holds, and fix what is wrong.

On the Magie tab each spell row gains a pencil button beside its existing delete button, in the same trailing arrangement the attack, inventory and equipped-item rows already use. Tapping the pencil — or tapping the row itself anywhere outside the prepared circle — opens the spell in the same dialog that created it, with all ten of its fields filled in: name, level, school, casting time, range, components, duration, description, damage. The player reads what they came for, edits whatever they want, and saves. Cancelling discards everything and leaves the spell untouched.

Saving writes the edit straight onto the character, like every other edit on the sheet — no separate save step — and the correction survives switching tabs and restarting the app. Changing a spell's level moves its row into the right level group in the list.

Preparation is not part of the dialog and is not disturbed by it. A prepared spell that is edited stays prepared, so fixing a typo never costs the player one of the day's prepared spells; an unprepared spell stays unprepared, so an edit never prepares something behind their back. The single exception: a spell edited down to cantrip level loses its preparation, silently — cantrips are always available and consume no daily choice, and leaving the flag set would draw a filled circle the player has no way to clear, since the toggle refuses cantrips.

That rule belongs to the Character, not to the tab. The Character gains a way to replace the spell at a given position with an edited one and to decide the prepared flag itself: it carries forward the flag of the spell already there, ignores whatever the caller passed, and clears it when the edited level is zero. This is also what fixes a live defect in the *add* flow, where the dialog builds a spell without a prepared flag at all — after this ticket the flag has exactly one entry point, the circle in the list, for both adding and editing.

Finally, the description field stops being the bottleneck in reading a spell. It is the only field that holds a paragraph and the main reason to open the detail at all, so instead of being capped at three lines it starts at three and grows with its content up to eight. A one-line cantrip note still renders a short field, so the dialog is unchanged for short spells.

Out of scope, as recorded in the spec: no separate read-only detail view, no delete confirmation, no reordering, duplicating, searching or importing of spells, no new fields on the spell, and no revision of the prepared-spell limit rule.

## Acceptance criteria

### Opening a spell

- [x] Each spell row shows a pencil button, placed before the delete button, styled as the pencil on the attack and inventory rows is.
- [x] Tapping the pencil opens the spell dialog.
- [x] Tapping the row outside the prepared circle opens the same dialog, through the same code path.
- [x] Tapping the prepared circle still toggles preparation and does not open the dialog.
- [x] The dialog opens with all ten of the spell's fields filled in with its current values.
- [x] The dialog's title is unchanged from the one used when adding a spell.
- [x] Adding a new spell still opens the same dialog with empty fields and works exactly as before.

### Saving and cancelling

- [x] Saving writes every edited field onto the character immediately, with no further save action required by the player.
- [x] Saving an edit leaves every other spell in the list untouched.
- [x] Cancelling the dialog changes nothing about the spell, including its prepared state.
- [x] An edit survives switching away from the Magie tab and back.
- [ ] An edit survives closing and reopening the app.
- [x] Editing a spell's level moves its row into that level's group in the list.
- [x] Deleting a spell still works with a single tap on the delete button, unchanged.

### Preparation under an edit

- [x] Editing a prepared, non-cantrip spell leaves it prepared.
- [x] Editing an unprepared spell leaves it unprepared.
- [x] The prepared flag the dialog hands to the model is ignored in both directions — preparation can never be set or cleared by editing a spell's descriptive fields.
- [x] Editing a prepared spell down to level zero clears its prepared flag, with no message shown.
- [x] Editing a cantrip up to a non-zero level leaves it unprepared.
- [x] The prepared count chip reads correctly after any edit.
- [x] An edit can never push the prepared count above the limit.
- [x] A spell added through the dialog arrives unprepared.

### The Character owns the write

- [x] Character exposes a single method that replaces the spell at a given position with an edited one, sitting with the other prepared-spell and spell-slot rules.
- [x] That method resolves the prepared flag itself, as described above.
- [x] A position outside the spell list is a no-op, consistent with the neighbouring spell-slot methods.
- [x] All ten descriptive fields are taken from the incoming spell.
- [x] The tab holds no copy of the prepared rule — it calls the model and renders the result.

### Reading a spell

- [x] The description field starts at three lines and grows with its content up to eight.
- [x] A spell with a short description opens a dialog no taller than it is today.
- [x] A description longer than eight lines remains fully readable inside the field.
- [x] The other nine fields keep their current single-line form, order and labels, and the dialog's width is unchanged.

### Tests

- [x] Model tests cover the new Character method at the Character seam, with no widget tree: prepared preserved, unprepared preserved, the caller's flag ignored both ways, cleared at level zero, unprepared when rising from level zero, all ten fields overwritten, an out-of-range position a no-op, the prepared count and over-limit flag correct afterwards, and a round trip through the Character's map serialisation.
- [x] One widget test at the existing character-sheet seam opens a sheet holding a prepared spell, opens that spell from its row, changes a field, saves, and asserts both that the change is on the live character and that the spell is still prepared.
- [x] No new test seam is introduced — the spell tab is not mounted on its own.
- [x] The widget test addresses the spell row's controls unambiguously. Worth knowing before writing it: the spell-slot circles and the prepared circle are drawn with overlapping icon vocabulary, so a sheet holding both spell slots and spells makes a bare icon locator ambiguous in a way the current Magie tests never hit.
- [x] Every existing model and widget test passes untouched.
- [x] `flutter analyze` clean; `flutter test` green.

## Comments

Implemented in `e5d9284`. `Character.updateSpell` owns the prepared-flag
rule; the Magie tab calls it and holds no copy of the rule. Nine model tests
cover every branch (flag carried forward in both directions, the caller's
flag ignored, cleared at level zero, unprepared when rising from level zero,
all ten fields overwritten, out-of-range a no-op, the count and over-limit
flag afterwards, and the map round trip), plus one widget test at the
character-sheet seam that opens a prepared spell from its row, edits it,
saves, and asserts both the change and the surviving prepared flag.

One criterion is left unticked: "An edit survives closing and reopening the
app." Nothing in this suite launches and relaunches the app, so it was not
verified end to end. What is verified is the step it rests on: the edit is
written through to the Database, asserted by the widget test. Persistence
across a relaunch then follows from the SQLite adapter's existing behaviour.
Stated as a deduction, not as a check.
