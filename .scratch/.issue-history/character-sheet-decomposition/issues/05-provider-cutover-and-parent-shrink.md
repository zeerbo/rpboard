# 05 — Shrink the parent screen and cut its read/save path over to characterProvider

**What to build:** With all seven tabs now split into their own widgets, `_CharacterSheetState` shrinks to exactly the four things the PRD calls for — the `TabController`, the current `Character`, the debounce `Timer`, and the save call — assembling the seven tab widgets into the `TabBarView`, each given the current `Character` and a shared "schedule save" callback. The screen stops loading its `Character` itself via a direct database call in `initState` and instead watches `characterProvider(id)`, rendering the `AsyncValue`'s loading, error, and missing-entity states the way the other four single-item-provider screens already do. The debounced save — still a 600ms timer, still flushed on dispose, timing completely unchanged — now calls `characterProvider(id).notifier.save()` instead of writing through the database seam and separately invalidating `characterListProvider`; the notifier's own invalidation is what keeps the character list fresh. A player who edits any field, on any tab, and returns to the character list sees their change reflected immediately, with no separate refresh step.

**Blocked by:** 02 — Split the Combattimento tab, 03 — Split the Magie tab, and 04 — Split the remaining five tabs (the parent can only shrink to its final shape once every tab owns its own fields); and single-item-providers 02 — Single-item Character provider and CharacterSheetScreen autosave cutover (C4; this ticket assumes `characterProvider(id)` and its `save()` method already exist).

**Status:** done

- [x] `_CharacterSheetState` (or its equivalent) holds only the `TabController`, the current `Character`, the debounce `Timer`, and the save call — no per-field state, no controller map, no `_initControllers`/`_syncFromControllers`
- [x] The screen reads via `ref.watch(characterProvider(id))` and renders loading / error / missing-entity / data states; a missing entity (e.g. deleted elsewhere) navigates back to the character list, matching today's "character not found" behavior
- [x] The debounced save calls `characterProvider(id).notifier.save(character)`; the direct `databaseProvider` write and the manual `characterListProvider` invalidation are both removed from the screen
- [x] The 600ms debounce interval and the cancel-timer-then-flush-on-dispose behavior are unchanged
- [x] Editing a field on any tab, leaving the sheet, and returning to the character list shows the edited value (e.g. name, HP) with no manual refresh
- [x] `flutter analyze` clean; save-path correctness relies on C4's existing `characterProvider` tests (`ProviderContainer` + `InMemoryDatabase`) — no new test seam is introduced here
