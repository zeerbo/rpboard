# 04 — Split Info, Statistiche, Equipaggiamento, Bio, and Note into their own widgets

**What to build:** The five tabs that carry no RPG rule this PRD moves — Info (name, race, class, subclass, level, background, alignment, player name, experience, inspiration checkbox), Statistiche (the six ability scores plus saving-throw and skill proficiency/expertise toggles), Equipaggiamento (the five coin fields and the inventory list with its add/edit dialog), Bio (personality traits, ideals, bonds, flaws, features, proficiencies/languages, backstory, appearance, physical description fields), and Note (the single free-text field) — each become their own widget file, each creating and owning only the `TextEditingController`s its own fields need, each writing every edit straight into the `Character` on change and notifying the parent to schedule a save. Ability modifiers, skill bonuses, saving-throw bonuses, and passive perception already lived on `Character` before this PRD and are read, not changed, by Statistiche. Completing this ticket empties the parent's `_initControllers` and `_syncFromControllers` entirely, since every field across all seven tabs now lives in the tab widget that owns it.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] Info, Statistiche, Equipaggiamento, Bio, and Note each live in their own widget file, each taking the current `Character` and a callback to schedule a save
- [x] Each widget owns `TextEditingController`s only for its own fields; none of these five tabs' fields remain in the parent's controller map
- [x] Statistiche's saving-throw and skill proficiency/expertise toggles, and its displayed bonuses, are unchanged in behavior (still reading `abilityMod`/`skillBonus`/`savingThrowBonus` from `Character`)
- [x] Equipaggiamento's inventory add/edit/delete flow and coin fields are unchanged in behavior
- [x] None of these five tabs' fields remain in the parent's `_initControllers`/`_syncFromControllers`; whatever is left there belongs to Combattimento or Magie and is emptied by tickets 02 and 03 (the parent's controller map is asserted gone in ticket 05, not here)
- [x] Widget test: editing a field in at least one of these five tabs updates the `Character`; switching away and back preserves the edit
- [x] `flutter analyze` clean; all five tabs behave identically to today
