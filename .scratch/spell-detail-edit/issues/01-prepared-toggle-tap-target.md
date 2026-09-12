# 01 — A real tap target for the prepared toggle

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

**Parent spec:** `.scratch/spell-detail-edit/PRD.md` — read it first; it records every decision and the alternatives that were rejected. This ticket implements only the "prepared circle gets a real hit target" decision, as a prefactor for ticket 02.

## What to build

A player preparing spells on the Magie tab can tap the prepared circle comfortably, without aiming at the icon itself.

Today the prepare/un-prepare gesture is bound to the circle glyph and nothing wider, so a tap that lands beside the circle does nothing at all. This ticket gives the circle an explicit, generous tap target across the whole leading area of the spell row.

Nothing about the behaviour changes. The circle still fills and empties on tap, still refuses a spell once the prepared limit is reached and still names that limit in a snack bar when it refuses, still does nothing at all on a cantrip and says nothing about it, and still leaves the row's appearance exactly as it is. This is purely the difference between a gesture the player has to aim at and one they can simply hit.

It lands first because ticket 02 makes the spell row itself tappable. Once that happens, any tap that misses the circle would open the spell's detail instead of preparing it — the two gestures would compete for the same corner of the row. Widening the target first means ticket 02 never introduces that competition, and it keeps the change that can regress the existing prepared-spell behaviour separate from the change that adds the new one.

## Acceptance criteria

### The gesture gets easier to hit

- [ ] Tapping anywhere in the spell row's leading area — not only on the circle glyph — toggles the spell's prepared state.
- [ ] The tap target is at least the size Flutter's own icon-button affordances use, so it is comfortable on a phone.
- [ ] The row's visual layout is unchanged: the circle is the same glyph at the same size, in the same position, with the same colours for prepared and unprepared.
- [ ] The rest of the row — name, the school / casting time / damage subtitle, the delete button — is unmoved and unchanged.

### Nothing about the rule changes

- [ ] Tapping an unprepared, non-cantrip spell below the limit prepares it, and the prepared count chip updates immediately.
- [ ] Tapping a prepared spell un-prepares it, and this is never refused, including from an over-limit state.
- [ ] Tapping an unprepared spell once the prepared limit is reached changes nothing and shows the snack bar naming the limit.
- [ ] Tapping a cantrip's circle changes nothing and shows no message.
- [ ] With the prepared limit at zero, every toggle is accepted and no chip is shown, exactly as before.

### Regression safety

- [ ] Every existing model test covering the prepared-spell limit passes untouched.
- [ ] Every existing widget test covering the Magie tab passes untouched. No existing widget test drives the prepared toggle today — the two Magie tests reach the spellcasting-ability field and the spell-slot circles — so this ticket should need no test edits at all. If one breaks, it is because the new target changed which widget a circle locator finds, and the fix is to make that locator address what it acts on rather than to loosen it.
- [ ] No change to the Character model in this ticket — the gesture's rule already lives there and is only called, never revised.
- [ ] `flutter analyze` is clean and the full test suite is green.
