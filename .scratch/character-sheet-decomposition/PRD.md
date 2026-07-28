Status: ready-for-agent

# Decompose CharacterSheetScreen

Implements architecture-review candidate **C7** (`docs/architecture-review.html#c7`). Last in the review's build sequence — C1 → C5 → C3 → C4 → C6 → C7 — and the largest of the set. Hard dependency on **C4** (single-item providers): this PRD assumes `characterProvider(id)` already exists and routes both the sheet's read and its save through it.

## Problem Statement

A player opens their Character sheet expecting to type into a field — an ability score, a spell slot, a death-save box — and have it just work: the right derived number appears, the edit survives switching tabs, and it's on disk a moment later without the player doing anything. Today most of that holds, but one corner is silently wrong: a player whose spellcasting ability is anything other than Intelligence sees a spell save DC and spell attack bonus computed as if they had no ability modifier at all, because the screen derives them from a shortcut that only happens to work for one of the six ability names. Separately, the single file behind the whole sheet has grown to the point where a developer touching one tab has to read past six others to find where a field's value round-trips, and the two lists that keep those 44 fields in sync (load into controllers, read back out of controllers) are exactly the kind of file-by-file duplication where a new field gets added to one list and forgotten in the other — a bug the player would only discover when a field they just edited quietly reverts.

## Solution

Move the handful of RPG rules that are still trapped in the screen — spellcasting DC/attack bonus (including a correct, case- and whitespace-insensitive mapping from the six Italian ability names), spell-slot set/use/restore, and death-save ticking/reset — onto `Character` itself, next to the ability-modifier, proficiency-bonus, skill-bonus, saving-throw-bonus and passive-perception logic that already lives there. This fixes the spellcasting-ability bug as a side effect of giving it a real, tested home instead of an inline string shortcut. Split the screen's seven tabs into seven widgets, each owning the `TextEditingController`s for its own fields and writing straight through into the `Character` on every change, so the parent screen shrinks to the tab machinery, the current `Character`, the debounce timer, and the save call — no more field-by-field copy-in/copy-out. The sheet reads its `Character` from `characterProvider(id)` and saves through `characterProvider(id).notifier.save()`, so the character list is never stale after an edit.

## User Stories

1. As a player, I want my spell save DC and spell attack bonus to be correct regardless of which ability I use for spellcasting, so that Bards, Sorcerers, Paladins and Clerics see the same accuracy Wizards already get.
2. As a player, I want to type "Carisma", "carisma", " Carisma " or "COSTITUZIONE" into the spellcasting-ability field and have it recognized, so that a small typing habit doesn't silently zero out my spellcasting numbers.
3. As a player who already filled in a spellcasting ability before this change, I want my saved text to keep working exactly as before, so that this refactor causes no re-entry of data I already typed.
4. As a player, I want to set, use, and restore spell slots per level, so that I can track my remaining casts during a session.
5. As a player, I want setting a spell slot level's total to 0 to remove that level's row, so that levels I don't have don't clutter the sheet.
6. As a player, I want spending a slot to stop once I've used them all, and restoring a slot to stop once none are spent, so that the counters can't go negative or over capacity.
7. As a player, I want to tick death-save successes and failures, have a later click "undo" back down to that box, and reset both counters, so that death saves behave the way they do at the table.
8. As a player, I want an edit I make in one tab to still be there if I switch to another tab and back, so that the sheet never appears to eat my input.
9. As a player, I want the character list I return to after editing a sheet to reflect what I just changed, so that I don't see stale data on the previous screen.
10. As a developer, I want spellcasting DC/attack-bonus derivation, ability-name normalization, spell-slot mutation, and death-save mutation living on `Character` as plain Dart, so that they're testable without pumping a widget.
11. As a developer, I want the six Italian ability names mapped to their short keys in one explicit, case/whitespace-insensitive place on the model, so that adding or fixing a mapping doesn't mean hunting through UI code.
12. As a developer, I want each of the seven tabs in its own file, each creating and owning only the controllers its own fields need, so that I can find and change one tab's fields without reading the other six.
13. As a developer, I want each tab to write its edits straight into the `Character` on change rather than through a central controller-to-model sync method, so that the class of bug where a field is added to one list but not the other stops being possible.
14. As a developer, I want the parent screen reduced to the `TabController`, the current `Character`, the debounce timer, and the save call, so that the file most developers have to touch stops being the largest in the repo.
15. As a developer, I want the sheet to read its `Character` from `characterProvider(id)` and save through `characterProvider(id).notifier.save()`, so that PG Mode gets the same list-freshness guarantee C4 already gives Master Mode's single-item screens.
16. As a developer picking up this file after the split, I want death saves' relationship to `isDead`/`isStable` decided and documented rather than left as two persisted columns nothing writes, so that I don't have to reverse-engineer intent from silence.
17. As a developer, I want the debounce interval and flush-on-dispose behavior unchanged, so that this PRD stays a structural refactor and not a behavior change to autosave timing.
18. As a developer, I want a table-driven test over all six ability names plus dirty input (wrong case, trailing whitespace, empty string, nonsense text) asserting the derived spell save DC and attack bonus, so that the bug this PRD fixes cannot regress silently.

## Implementation Decisions

- **Framing correction.** Ability modifiers, proficiency bonus, skill bonuses, saving-throw bonuses and passive perception already live on `Character` — the review's "no rules in the model" claim does not hold for those. What is actually stranded in the UI, and what this PRD moves, is a smaller and specific set: spellcasting DC/attack bonus plus ability-name normalization, spell-slot mutation, and death-save mutation.
- **Spellcasting derivation moves to `Character`.** `spellSaveDC` and `spellAttackBonus` become derived members on `Character`, built from the existing `abilityMod`/`proficiencyBonus`. They replace the screen's inline `spellcastingAbility.toLowerCase().substring(0,3)`, which happens to work for `'Intelligenza'` → `'int'` but silently yields modifier 0 for `'Carisma'`, `'Costituzione'`, and anything else that doesn't fall in the first three matching letters.
- **Ability-name normalization is explicit, not positional.** The model gets an explicit mapping from the six Italian ability names (Forza, Destrezza, Costituzione, Intelligenza, Saggezza, Carisma) to their short keys (`str`/`dex`/`con`/`int`/`wis`/`cha`), case-insensitive and tolerant of surrounding whitespace, falling back to a zero modifier for anything unrecognized. No substring slicing.
- **The `spellcastingAbility` field stays free text.** This PRD does not introduce a dropdown or enum for it. Because normalization is tolerant of case and whitespace, every already-persisted value that named a real ability correctly keeps working after this change without any data migration.
- **Spell slots move to `Character`.** Set-total, use, and restore become methods on `Character`, preserving today's exact clamps: setting a level's total to 0 removes that level's row; using a slot only succeeds while `used < total`; restoring a slot only succeeds while `used > 0`.
- **Death saves move to `Character`.** Ticking a success box or a failure box preserves the current toggle semantics: clicking box `i` sets the count to `i` if the count was already above `i`, otherwise sets it to `i + 1`. A reset method zeroes both counters.
- **`isDead`/`isStable` get an explicit decision.** These are persisted columns nothing currently writes. `Character` starts maintaining them from the death-save counts as a side effect of the death-save mutation methods (three failures → dead; three successes → stable, resetting both counters), so the columns finally mean something instead of sitting inert. Whichever exact threshold semantics are implemented, they must be stated plainly in this file's final form — silently leaving the fields unwritten is not an acceptable fallback once this PRD ships.
- **Hit dice stay untouched.** `hitDiceUsed` is a free-text field today with no rules behind it; this PRD adds none. Extracting hit-dice usage rules would be new behavior, not a move of existing behavior, and is explicitly not part of this change.
- **Seven tabs become seven widgets.** Info, Statistiche, Combattimento, Equipaggiamento, Magie, Bio, and Note each become their own file under the PG screens directory. Each tab widget creates the `TextEditingController`s for only its own fields.
- **Write-through-on-change, not sync-on-save.** Each tab writes a field's new value straight into the `Character` object as soon as it changes, and notifies the parent to schedule a save — there is no batch copy-out step. This is what `_syncFromControllers` did today, in one 46-line method covering every field across every tab; it and its counterpart `_initControllers` (42 lines) disappear entirely, and with them the class of bug where a field is added to one list but not the other.
- **Write-through is required, not just simpler, because of `TabBarView` disposal.** `TabBarView` can dispose off-screen tabs' widgets (and their controllers) once the user has scrolled past them. A sync-on-save design would need every tab's controllers alive at save time, which off-screen disposal breaks. Because each tab writes its edits into the `Character` the moment they happen, the `Character` object is always current regardless of which tabs are currently built, and the save path never needs to reach into a possibly-disposed tab's controllers.
- **Rejected: controller map stays in the parent, passed down to tabs.** Keeps the parent large and makes every tab depend on a string-keyed map it doesn't own, which is the same fragility the split is meant to remove, just moved down one level.
- **Rejected: rules-only extraction with no UI split.** Fixes the spellcasting bug and adds tests, but leaves the file well over a thousand lines and does nothing about the controller-list duplication that caused the bug's shape in the first place.
- **The parent screen keeps four things.** After the split, `_CharacterSheetState` (or its equivalent) owns only the `TabController`, the current `Character`, the debounce `Timer`, and the call to save — no per-field state, no controller map, no sync methods.
- **Reads move to `characterProvider(id)` (C4).** The screen stops loading the `Character` itself in `initState` via a direct database call and instead watches the single-item provider C4 introduces.
- **Saves move to `characterProvider(id).notifier.save()`.** The debounced save calls the C4 notifier's `save()` instead of calling the database seam directly and separately invalidating `characterListProvider`; the notifier's own `invalidateSelf()` is what keeps the character list fresh after an edit, matching how C4 already does it for Master Mode's single-item screens.
- **Debounce interval and flush-on-dispose are unchanged.** The 600ms scheduled-save timer and the "cancel timer, flush a save on dispose" behavior carry over exactly as they are today; only what gets called at the end of that timer changes.
- **No schema change.** No column is added, removed, or renamed. The only user-visible change is that spell save DC and spell attack bonus become correct for spellcasting abilities other than Intelligence.

## Testing Decisions

- **Moved rules are tested as pure Dart on `Character`, no Flutter.** A table-driven test covers all six Italian ability names, plus dirty input (wrong case, trailing/leading whitespace, empty string, unrecognized text), asserting the derived spell save DC and spell attack bonus in each case, including that unrecognized input falls back to a zero modifier rather than throwing or matching the wrong ability.
- **Spell-slot tests cover set/use/restore and both clamps**, plus the remove-at-zero-total case, as pure Dart on `Character`.
- **Death-save tests cover ticking, the toggle-down behavior, reset, and whatever `isDead`/`isStable` end up meaning** once that decision is finalized — asserted as pure Dart on `Character`.
- **A small number of widget tests, only for what pure-Dart tests can't reach:** that editing a field inside a tab writes through into the `Character`, and that switching away from a tab and back does not lose an edit made in it (the scenario write-through-on-change is specifically meant to protect against).
- **The save path is covered by C4's `characterProvider` tests**, through the existing `databaseProvider` seam overridden with `InMemoryDatabase` in a `ProviderContainer` — this PRD does not introduce a new seam for the debounce, and debounce timing itself is not worth a test.
- **Assert external behavior only:** derived values (`spellSaveDC`, `spellAttackBonus`, skill/saving-throw bonuses already covered elsewhere) and persisted state (spell slots, death-save counters, `isDead`/`isStable`). Never assert on private fields, controller maps, or other widget internals.
- **Prior art:** `test/models/component_test.dart` for pure-Dart, no-Flutter model tests; `test/providers/*_test.dart` for the `ProviderContainer` + `InMemoryDatabase` pattern the save-path coverage relies on.

## Out of Scope

- Hit-dice usage rules — `hitDiceUsed` stays a free-text field with no derived behavior.
- Short/long rest mechanics.
- Any redesign of the sheet's visual layout — this is a structural split, not a UI refresh.
- Encumbrance or currency-conversion rules.
- Validation of ability score ranges.
- The `Attack`, `InventoryItem`, and `Spell` value objects, beyond the specific rules this PRD moves (they are otherwise untouched).
- Introducing a dropdown or enum for the spellcasting ability — the field stays free text.
- C4 itself (single-item providers). This PRD assumes `characterProvider(id)` and its `save()` method already exist and only wires the sheet to use them.

## Further Notes

- This is the last item in the review's sequence (C1 → C5 → C3 → C4 → C6 → C7) and its largest, both in lines touched and in the number of small decisions (ability-name normalization, slot clamps, death-save semantics, `isDead`/`isStable`) that had to be pinned down rather than left implicit.
- The spellcasting-ability bug is a good illustration of why the rules belonged on the model in the first place: `'Intelligenza'.substring(0,3)` happening to equal `'int'` is coincidence, not design, and no amount of UI testing would have surfaced that `'Carisma'` and `'Costituzione'` silently fail the same shortcut. Once the mapping is an explicit table instead of a slice, the bug class it belongs to (five other coincidental matches that don't exist) can't recur.
- The `TabBarView`-disposal hazard is the reason write-through-on-change is a correctness requirement here, not a style preference — it's worth keeping in the front of mind if a future change to the tab structure (e.g. lazy tab building, `PageStorageKey` changes) is made, since it's what currently keeps a not-yet-built or already-disposed tab from ever being a source of stale data.
