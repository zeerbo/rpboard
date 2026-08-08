# 02 — Single-item Character provider and CharacterSheetScreen autosave cutover

**What to build:** A `characterProvider(id)` joins the provider graph the same way, backed by the existing `Database.getCharacter`/`updateCharacter`. `CharacterSheetScreen` — the sharpest bug this PRD exists to fix — stops loading its Character by hand in `initState` and stops debounce-saving straight through a direct seam write with a manual list-provider invalidation afterward: it `ref.watch(characterProvider(characterId))` for the initial load, and its debounce-flush save calls `characterProvider(characterId).notifier.save(...)`, which owns invalidating both itself and `characterListProvider`. The 600ms debounce timer and the dispose-time flush are left exactly as they are — only the write target changes. A player editing their character sheet and switching back to "my characters" sees their latest name, level, or HP immediately, with no stale row.

**Blocked by:** Nothing technical — `Database.getCharacter` already exists and C3 (atomic reordering) touches none of the files this ticket touches. Sequenced after C3 only because the maintainer has decided C3 lands before C4 as a whole; if C3 is already underway on other branches, this ticket can safely run alongside it.

**Status:** done

- [x] `characterProvider` is an `AsyncNotifierProvider.family<..., Character?, String>` keyed by character id; `build(id)` calls `Database.getCharacter(id)` and returns its result, including `null`, without throwing
- [x] `characterProvider(id).notifier.save(Character)` writes through `Database.updateCharacter`, calls `ref.invalidateSelf()`, then invalidates `characterListProvider`
- [x] `CharacterSheetScreen`'s initial load comes from `ref.watch(characterProvider(characterId))` rather than a hand-rolled seam read plus `setState`
- [x] `CharacterSheetScreen`'s debounce-flush save calls `characterProvider(characterId).notifier.save(...)`; the direct `Database.updateCharacter(...)` call and the manual `characterListProvider` invalidation are removed from the screen
- [x] The 600ms debounce `Timer` and the dispose-time flush (save-on-dispose) are unchanged in timing and behavior
- [x] A missing Character (e.g. cascade-deleted elsewhere) is still handled explicitly — the existing redirect-to-character-list behavior for a not-found character is preserved
- [x] A `ProviderContainer` test overriding `databaseProvider` with the `InMemoryDatabase` fake covers: `build` returns the correct Character for a known id; `build` for an unknown id returns `null` without throwing; `save` is observable on a subsequent read of `characterProvider(id)`; after `save`, re-reading `characterListProvider` reflects the change (the anti-stale regression test — this is the PRD's headline bug fix)
- [x] `flutter analyze` clean; full `flutter test` green
- [x] Manually verified: editing a character sheet field, waiting past the debounce (or navigating back immediately), then opening the character list shows the edit with no stale copy
