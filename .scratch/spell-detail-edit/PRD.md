# Spell detail: consulting and editing a spell on the Magie tab

Status: ready-for-agent

## Problem Statement

A player who enters a spell on the Magie tab enters it once and for all. The spell list offers exactly two gestures per row: prepare/un-prepare, and delete. There is no way to reopen a spell that has already been saved.

This costs the player twice.

It costs them **consultation**. A Spell carries ten fields, and the row shows four of them — name, school, casting time, damage. Range, components, duration and the description are written into the sheet and then never displayed anywhere. The player types out "V, S, un fiocco di lana" and a full paragraph of rules text, and from that moment the app is the one place those words cannot be read. At the table, the question "what is the range on this?" sends them back to the rulebook they were trying to replace.

It costs them **correction**. A typo, a wrong level, a damage die entered as `8d8` instead of `8d6`, a description pasted with a line missing — every one of these is permanent. The only recovery is to delete the spell and retype all ten fields from scratch, which also throws away its prepared state. A single mistyped character costs a full re-entry.

The gap is local to this one list. Attacks, inventory items and equipped items all already open for editing from their row. The spell list is the only list on the character sheet that does not.

## Solution

A spell row opens. Tapping the row — or its pencil button, sitting beside the existing delete button exactly as it does on the attack and inventory rows — reopens the spell in the same dialog that created it, with all ten fields filled in. The player reads what they need, changes what is wrong, and saves. Nothing else about the row changes.

Consultation and correction are served by the one dialog rather than by a separate read-only view. The dialog already shows every field a Spell has; what it lacked was a way in. The description field, the one field that holds a paragraph rather than a phrase, grows to fit what is in it instead of being capped at three lines, so that reading a real spell description inside it is comfortable.

Preparation stays out of the dialog entirely. Whether a spell is prepared is governed by the circle in the list and by the Character's limit rule, and the dialog neither shows that flag nor disturbs it: saving an edit to a prepared spell leaves it prepared. The one exception is a spell edited down to cantrip level, which cannot be prepared at all — that spell loses its preparation, because the player has just declared it to be something that never consumes a daily choice.

Because the row itself becomes tappable, the prepared circle gets a hit target worth tapping. Today the gesture is bound to the icon alone.

## User Stories

1. As a player who entered a spell, I want to reopen it, so that entering it once does not mean living with it forever.
2. As a player who mistyped a spell's name, I want to correct the name, so that my list reads the way my character sheet should.
3. As a player who entered the wrong level for a spell, I want to correct the level, so that the spell sits in the right group in my list.
4. As a player who entered the wrong damage expression, I want to correct it, so that I roll the right dice at the table.
5. As a player who wants to check a spell's range mid-combat, I want to read its range in the app, so that I do not reach for the rulebook.
6. As a player who wants to check a spell's components, I want to read them in the app, so that I know whether I can cast it while bound or silenced.
7. As a player who wants to check a spell's duration, I want to read it in the app, so that I know how long a concentration effect lasts.
8. As a player who wants to re-read what a spell actually does, I want to read its full description in the app, so that the paragraph I typed is not write-only.
9. As a player reading a long description, I want the field to show more than three lines at a time, so that reading a real spell's rules text is not done through a slot.
10. As a player reading a short description, I want the dialog to stay the size it is today, so that a cantrip's one-line note does not open a tall empty box.
11. As a player who opens a spell only to look at it, I want to close the dialog without saving, so that consulting a spell can never alter it.
12. As a player who opens a spell and changes my mind mid-edit, I want cancelling to discard every change I made in the dialog, so that a half-finished edit never lands on my sheet.
13. As a player who cancels an edit, I want the spell left exactly as it was, including its prepared state, so that cancelling is genuinely free.
14. As a player looking at a row, I want a visible pencil button, so that I can see that the spell is editable without having to discover it.
15. As a player who has understood the list, I want tapping the row itself to open the spell, so that consulting a spell takes one tap and not an aimed one.
16. As a player used to the rest of my sheet, I want the pencil to sit where it sits on my attacks and my inventory, so that one habit works across every list I have.
17. As a player who edits a prepared spell, I want it to stay prepared, so that fixing a typo does not silently cost me one of today's prepared spells.
18. As a player who edits an unprepared spell, I want it to stay unprepared, so that an edit never prepares something behind my back.
19. As a player who edits a spell, I want nothing about my other spells to change, so that one edit touches one spell.
20. As a player who edits a spell, I want the prepared count chip to still read correctly afterwards, so that the number I rely on during preparation stays trustworthy.
21. As a player who edits a spell's level, I want the row to move to the right level group in the list, so that the list keeps telling me the truth about what I know.
22. As a player who edits a prepared spell down to cantrip level, I want it to stop being prepared, so that I am not left with a checked circle I have no way to uncheck.
23. As a player who edits a cantrip up to a real spell level, I want it to arrive unprepared, so that I choose deliberately whether it is one of today's picks.
24. As a player preparing spells, I want the circle to have a comfortable tap target, so that preparing a spell never misfires into opening its detail.
25. As a player preparing spells, I want the circle to keep behaving exactly as it does today, so that making the row tappable costs me nothing I already had.
26. As a player who edits a spell, I want the change saved to my character without pressing any further save button, so that editing a spell works like every other edit on my sheet.
27. As a player who edits a spell, I want the change to survive switching to another tab and back, so that navigation never loses my correction.
28. As a player who edits a spell, I want the change to survive closing and reopening the app, so that the correction is permanent in the way the mistake used to be.
29. As a player who deletes a spell, I want delete to keep working exactly as it does today, so that a new gesture on the row does not complicate the one I already use.
30. As a player who adds a new spell, I want the add flow unchanged, so that a feature about editing does not disturb the one that already worked.
31. As a player of a class that prepares nothing, I want editing to work the same for me, so that a feature about spell detail is not really a feature about preparation.
32. As an existing user upgrading the app, I want every spell already on my sheet to open for editing, so that the feature applies to the spells I entered before it existed.
33. As an existing user upgrading the app, I want my spells and their prepared flags untouched by the upgrade, so that the upgrade costs me no data.
34. As a developer, I want the rules about what an edit does to the prepared flag to live on the Character, so that no future screen writing a spell can break them.
35. As a developer, I want one code path that writes a spell into a Character, so that "what happens to preparation when a spell changes" has exactly one answer.

## Implementation Decisions

### Editing reuses the existing spell dialog; no read-only detail view is built

The dialog that creates a spell already takes an initial Spell and pre-fills all ten of its fields from it — it was written to be reusable for editing and has simply never been called that way. Editing therefore adds a caller, not a dialog.

A separate read-only detail view was considered and rejected. It would show a description as flowing text rather than inside a field, which reads better, but it costs a second surface to build and maintain, adds a step between "I want to look at this" and "I want to fix this", and would make the spell list the only list on the character sheet with a two-stage detail flow. The chosen trade is to make the one editable surface pleasant to read — see the description field decision below — rather than to build two.

### Two triggers: a pencil button and a tap on the row

The row gains a pencil icon button placed before the existing delete button, matching the trailing-icon arrangement already used by the attack row, the inventory row and the equipped-item row. It also gains a row-level tap that opens the same dialog. The pencil is the discoverable affordance; the row tap is the fast one. Both call the same code path — there is no second behaviour to keep in step.

### The dialog never carries the prepared flag

The dialog's save currently constructs a brand-new Spell from its ten text fields and does not pass `prepared`, so the constructed Spell is unprepared by default. This is harmless for adding (a new spell *is* unprepared) and destructive for editing (correcting a typo would un-prepare the spell).

The fix is not to add `prepared` to the dialog. Preparation has exactly one player-facing gesture — the circle in the list — and that gesture is gated by `Character.togglePreparedSpell`, which owns the prepared-spell limit. A checkbox in the dialog would be a second entry point to the same state, one that bypasses the limit unless the rule were duplicated there. The dialog stays a pure editor of the spell's ten descriptive fields, and the flag is resolved by the model at write time.

### Character owns the write, through a new `updateSpell` method

CONTEXT.md's Character entry states that a rule computable from a Character belongs to the Character, not to the screen showing it; the spell-slot and prepared-spell rules already live there. Character therefore gains a method that replaces the spell at a given index with an edited one and decides its prepared flag itself:

- The incoming spell's `prepared` value is **ignored**. The method reads the prepared state of the spell currently at that index and carries it forward. Callers cannot set preparation by editing, whatever they pass.
- If the edited spell's level is zero, the carried-forward flag is cleared (see the next decision).
- An index outside the spell list is a no-op, consistent with the neighbouring spell-slot methods, which no-op on a level they hold no row for.
- All ten descriptive fields are taken from the incoming spell.

This makes the dialog's missing `prepared` argument structurally irrelevant rather than patched: there is no path from the dialog to that flag at all.

### Dropping a spell to cantrip level clears its preparation, silently

Character already holds two facts about cantrips: they are excluded from the prepared count, and `togglePreparedSpell` refuses them outright, so a cantrip can never *become* prepared. Editability opens a third door that those two rules do not cover — a prepared spell edited down to level zero. Its flag would survive the edit, the row would keep drawing a filled circle (the row reads the flag directly), and the toggle that could clear it refuses cantrips. The result is a checked circle the player cannot uncheck: a state the model says is impossible.

`updateSpell` therefore clears the flag when the edited level is zero. No message is shown. The player has just declared the spell a cantrip, cantrips are always available and consume no daily choice, so nothing of value was taken from them; a snack bar here would be a second message in a tab that already has one, for a case whose outcome is self-evident.

This also keeps intact the documented claim that being over the prepared limit is reachable only by lowering the limit: an edit can never raise the prepared count, because a spell arriving at a non-zero level from level zero was necessarily unprepared.

### The prepared circle gets a real hit target

The prepare/un-prepare gesture is currently bound to the twenty-pixel icon itself, with no wider target around it. With the row tappable, a tap that lands near the circle without landing on it would open the detail dialog instead of preparing the spell — the two gestures would compete for the same corner of the row.

The circle is therefore given an explicit, larger tap target so the preparation gesture cannot miss and fall through to the row. Its behaviour is unchanged: same rule, same refusal message, same inert toggle for cantrips.

### The description field grows

The description is the only one of the ten fields that holds a paragraph, and it is the field the player opens the detail to read. It is capped at three lines today. It becomes a field that starts at three lines and grows with its content up to eight, so a real spell description can be read without the field being the constraint. The dialog's content is already scrollable, so a taller field needs no other layout change, and a short description still renders a short field.

### The dialog title stays a plain noun

The title reads "Incantesimo" for both adding and editing. Every sibling dialog on the character sheet ("Attacco", "Oggetto", "Oggetto Equipaggiato", "Armatura", "Bonus") uses a single fixed noun for both cases, and the filled fields already tell the player which case they are in. Distinguishing the two would add a parameter to the dialog and make this tab the only one that does it.

## Testing Decisions

A good test here states what a player can observe and nothing about how it is arranged: that a saved spell can be reopened with its values in it, that an edit lands on the Character, that preparation survives or is cleared under the stated rule. Tests assert against the Character and against what the sheet renders — never against which widget holds which callback, so that the row's layout can change without a test failing.

Two seams, both already in use in this repo. No new seam is introduced.

**`Character`, in the pure-Dart model tests.** This is the highest seam for the rule and needs no widget tree. It carries the whole of `updateSpell`:

- an edit preserves the prepared flag of a prepared spell
- an edit preserves the unprepared state of an unprepared spell
- the `prepared` value passed in by the caller is ignored in both directions
- an edit whose level is zero clears the prepared flag
- an edit from level zero to a non-zero level leaves the spell unprepared
- all ten descriptive fields are overwritten by the incoming spell
- an out-of-range index changes nothing
- the prepared count and the over-limit flag read correctly after an edit
- an edit round-trips through the Character's map serialisation

Prior art: the `Character prepared-spell limit` group, which covers `togglePreparedSpell` the same way — every branch of the rule, no widgets.

**`CharacterSheetScreen`, in the widget tests.** The full screen is mounted inside a Riverpod container with the in-memory Database fake, which is how every existing character-sheet widget test is written, including the two in the `Magie tab` group. One test here proves the wiring that model tests cannot reach: open a sheet holding a prepared spell, open that spell from its row, change a field, save, and assert both that the change is visible on the live Character and that the spell is still prepared. That single test covers the trigger, the dialog's pre-fill, and the model call in one pass.

Prior art: the existing `Magie tab` tests and `adding an armor writes it through and updates the shown final CA`, which drive a dialog from a mounted sheet and assert on the Character behind it. The existing helpers for mounting, tab-switching and explicit unmounting are reused as-is.

## Out of Scope

- **A read-only spell detail view.** Considered and rejected above.
- **Confirming spell deletion.** The delete button remains a single tap, as it is for attacks and inventory items. Making the row interactive is not a reason to make this list the only one that confirms; if deletion should confirm, it should confirm everywhere, as its own change.
- **Reordering spells.** The list is grouped by level and ordered by insertion within each group. A drag order would require a persisted position on the Spell and a schema change.
- **Duplicating a spell**, searching or filtering the list, and importing spells from a compendium.
- **Any change to the prepared-spell limit rule**, to the spell-slot rows, or to the derived spellcasting chips. The limit's behaviour is only *consumed* here, never revised.
- **Changing the add flow.** Adding a spell keeps working exactly as it does, and gains only the description field's new height.
- **Changing the dialog's layout**, field order, or width beyond the description field.
- **Making the Spell model richer** — no new fields, no concentration flag, no ritual flag, no per-level upcasting data.

## Further Notes

The change fixes a live defect in the add flow as a side effect, not just a hypothetical one in the new edit flow: once the prepared flag is resolved by the Character rather than assembled in the dialog, the flag has exactly one entry point for both adding and editing.

No schema change and no Migration. The spell list is persisted as JSON inside a single existing column of the Character's row, and Spell gains no field.

No ADR is proposed. The feature introduces no new vocabulary — Spell, Character and the prepared-spell rules are already defined in CONTEXT.md — and no decision here is expensive to reverse: the rejected read-only view could be added later on top of the same model method without unpicking anything. `updateSpell` is an instance of the rule CONTEXT.md's Character entry already states, not a new principle.
