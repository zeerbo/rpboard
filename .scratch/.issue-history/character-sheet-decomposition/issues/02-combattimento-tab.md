# 02 — Split the Combattimento tab into its own widget

**What to build:** The Combattimento tab — hit points, the heal/damage dialog, AC/initiative/speed/hit-dice fields, death saves, and the attack list with its add/edit dialog — becomes its own widget file under the PG screens directory, creating and owning the `TextEditingController`s for only its own fields instead of sharing the parent's controller map. Every edit (typing a number, confirming a heal/damage amount, adding or deleting an attack, ticking or resetting a death save) writes straight into the `Character` the moment it happens and notifies the parent to schedule a save, instead of going through the parent's `_syncFromControllers`/`_initControllers`. The death-save checkboxes and reset button call the tick/reset methods `Character` gained in ticket 01, so `isDead`/`isStable` start being maintained the moment a player ticks a box, instead of the screen doing the count math inline. A player who edits anything in this tab, switches to another tab, and switches back sees every change exactly as they left it.

**Blocked by:** 01 — Move spellcasting, spell-slot, and death-save rules onto Character.

**Status:** done

- [x] Combattimento lives in its own widget file, taking the current `Character` and a callback to schedule a save
- [x] The widget owns `TextEditingController`s only for its own fields (HP max/current/temp, AC, initiative, speed, hit dice, hit dice used); none of these remain in the parent's controller map or `_initControllers`/`_syncFromControllers`
- [x] Death-save checkboxes and the reset button call `Character`'s tick/reset methods from ticket 01; no inline death-save count math remains in the widget
- [x] The heal/damage dialog and the attack add/edit/delete flow are unchanged in behavior and write straight into the `Character`
- [x] Widget test: editing a field in this tab (e.g. AC) updates the `Character`; switching to another tab and back preserves the edit
- [x] Widget test: ticking a death-save box and switching tabs and back preserves the tick, and ticking the third success/failure box results in the corresponding `isDead`/`isStable` on the `Character`
- [x] `flutter analyze` clean; Combattimento behaves identically to today (HP, AC, attacks, death-save ticking/reset), with `isDead`/`isStable` now actually being written
