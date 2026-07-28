# 01 — Move spellcasting, spell-slot, and death-save rules onto Character

**What to build:** `Character` gains the handful of RPG rules still trapped in the screen, next to the ability-modifier, proficiency-bonus, skill-bonus, saving-throw-bonus and passive-perception logic that already lives there. `spellSaveDC` and `spellAttackBonus` become derived members built from an explicit, case- and whitespace-insensitive mapping of the six Italian ability names (Forza, Destrezza, Costituzione, Intelligenza, Saggezza, Carisma) to their short keys (`str`/`dex`/`con`/`int`/`wis`/`cha`) — replacing the `spellcastingAbility.toLowerCase().substring(0,3)` shortcut that only coincidentally equals `'int'` for Intelligenza and silently yields a zero modifier for every other ability, with unrecognized or empty text also falling back to a zero modifier rather than throwing. `Character` also gains spell-slot mutation (set a level's total, use a slot, restore a slot) preserving today's exact clamps, and death-save mutation (tick a success/failure box with the existing toggle-down semantics, reset both counters) that additionally starts maintaining `isDead`/`isStable`: reaching three failures sets `isDead` and resets both counters, reaching three successes sets `isStable` and resets both counters — finally giving those two persisted-but-inert columns real meaning. Nothing in the screen calls these new members yet; that happens as the tab-split tickets replace each tab's inline logic with calls onto `Character`.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] `Character` exposes `spellSaveDC` (`8 + proficiencyBonus + mod`) and `spellAttackBonus` (`proficiencyBonus + mod`), where `mod` comes from `abilityMod` applied to the normalized `spellcastingAbility`
- [x] An explicit lookup covers all six Italian ability names case-insensitively and tolerant of leading/trailing whitespace; anything unrecognized (including an empty string) yields a zero modifier instead of throwing or matching by coincidence; no substring slicing remains
- [x] `spellcastingAbility` stays a free-text `String` field — no dropdown or enum introduced
- [x] `Character` gains a set-total method for a spell-slot level that removes that level's row when the total is set to `0`, a use method that is a no-op once `used == total`, and a restore method that is a no-op once `used == 0`
- [x] `Character` gains tick-success/tick-failure methods preserving the existing toggle-down semantics (clicking box `i` sets the count to `i` if it was already above `i`, otherwise `i + 1`) and a reset method zeroing both death-save counters
- [x] Reaching 3 death-save failures sets `isDead = true` and resets both counters to `0`; reaching 3 death-save successes sets `isStable = true` and resets both counters to `0`
- [x] A table-driven test covers all six ability names (mixed case, leading/trailing whitespace) plus dirty input (empty string, unrecognized text), asserting `spellSaveDC` and `spellAttackBonus` in every case
- [x] Pure-Dart tests cover spell-slot set/use/restore, both clamps, and the remove-at-zero-total case
- [x] Pure-Dart tests cover death-save ticking, the toggle-down behavior, reset, and the `isDead`/`isStable` side effects
- [x] `flutter analyze` clean; the running screen is unaffected — it still uses its own inline logic until the tab-split tickets rewire it onto these new members
