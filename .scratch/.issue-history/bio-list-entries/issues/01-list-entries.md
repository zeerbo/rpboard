Status: ready-for-agent

# 01 — Linguaggi + Talenti as list entries

Implements [PRD](../PRD.md). Single commit, suite green.

## Model ([lib/models/character.dart](../../../lib/models/character.dart))

- Add class `CharacterFeature { String title; String description; }` with `toJson`/`fromJson`, next to `EquipmentItem`.
- Replace field `String profsAndLanguages` → `List<String> languages`; `String featuresAndTraits` → `List<CharacterFeature> features`. Update constructor (nullable param → `?? []`).
- `fromMap` (`profs_and_languages`, `features_and_traits`):
  - value trimmed starts with `[` → `jsonDecode` list. Languages: cast each to `String`. Features: `CharacterFeature.fromJson` each.
  - else legacy: split on `\n`, trim, drop empties. Languages: the strings. Features: `CharacterFeature(title:'', description: line)`.
  - null/empty → `[]`. Guard decode in try/catch → `[]` on failure (match existing `parseX` helpers).
- `toMap`: prune then `jsonEncode`.
  - `languages`: drop entries where `trim().isEmpty`.
  - `features`: drop entries where `title.trim().isEmpty && description.trim().isEmpty`. Encode via `toJson`.

## UI ([lib/screens/pg/character_sheet/bio_tab.dart](../../../lib/screens/pg/character_sheet/bio_tab.dart))

Replace the two `SheetTextField`s at lines ~115–129.

- Drop `_featuresAndTraits` / `_profsAndLanguages` single controllers.
- Manage per-entry controllers in lists; create on add, dispose on remove and in `dispose()`.
- **Linguaggi** block: `SectionHeader('Linguaggi')`; vertical list — each row = `Expanded(SheetTextField)` + `IconButton` remove; "aggiungi" button (append empty language + controller).
- **Caratteristiche e Talenti** block: `SectionHeader`; per entry a bordered `Card`/`Container` — title `SheetTextField` (single line) on top, description `SheetTextField(multiline:true)` below, remove icon top-right; "aggiungi" button.
- Every edit routes through `_edit(...)` so `onChanged` fires and `c.languages` / `c.features` stay in sync.
- Follow existing add/remove list-edit style used elsewhere in the app (equipment) for consistency.

## Tests ([test/models/](../../../test/models/))

- Legacy `profs_and_languages` multi-line → `languages` (per line, blanks skipped).
- Legacy `features_and_traits` multi-line → `features` (description=line, title='').
- New JSON-list value round-trips.
- `toMap` prunes empty language and empty-title+desc feature; keeps partial.
- `fromMap(toMap())` round-trip preserves populated lists.

## Definition of done

- `flutter analyze` clean, `flutter test` green.
- Add/remove works for both blocks; reload preserves entries; blanks pruned.
- Legacy characters load with old text folded into entries, nothing lost.
