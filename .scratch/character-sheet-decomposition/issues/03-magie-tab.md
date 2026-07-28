# 03 — Split the Magie tab into its own widget

**What to build:** The Magie tab — the spellcasting-ability field, the derived spell save DC / spell attack bonus display, the nine spell-slot rows, and the spell list with its add/delete flow — becomes its own widget file, owning controllers only for its own fields (the spellcasting-ability text field and the spell-add dialog's fields) and reading `spellSaveDC`/`spellAttackBonus` straight from `Character` instead of the inline `substring(0,3)` shortcut. Spell-slot rows call the set-total/use/restore methods `Character` gained in ticket 01. This ticket ships the PRD's headline fix: a player typing "Carisma", "carisma", " Carisma ", or "COSTITUZIONE" into the spellcasting-ability field now sees an accurate spell save DC and attack bonus — the same accuracy Wizards typing "Intelligenza" already got by coincidence — and a value a player already typed before this change keeps working with no re-entry, because the new normalization is tolerant of exactly the case and whitespace variance real players type.

**Blocked by:** 01 — Move spellcasting, spell-slot, and death-save rules onto Character.

**Status:** done

- [x] Magie lives in its own widget file, owning controllers only for its own fields (spellcasting-ability text field, spell-dialog fields)
- [x] The tab displays `Character.spellSaveDC`/`Character.spellAttackBonus`; the inline `substring(0,3)` computation is deleted from the screen entirely
- [x] Spell-slot rows (set total, use, restore) call `Character`'s set-total/use/restore methods from ticket 01; setting a level's total to 0 still removes that level's row from view
- [x] Typing any of the six Italian ability names, in any case or with surrounding whitespace, produces the correct spell save DC and spell attack bonus; unrecognized text shows the zero-modifier values rather than a stale or wrong number
- [x] Adding, toggling "prepared" on, and deleting a spell still write straight into `Character.spells`
- [x] Widget test: editing the spellcasting-ability field updates the `Character` and the displayed DC/attack bonus recompute; switching away from Magie and back preserves the field, the spell-slot used/total state, and the spell list
- [x] `flutter analyze` clean
