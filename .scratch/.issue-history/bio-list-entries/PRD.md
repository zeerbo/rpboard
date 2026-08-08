Status: ready-for-agent

# Bio tab: list entries for Linguaggi and Caratteristiche e Talenti

## Problem Statement

In the Bio tab of the character sheet ([bio_tab.dart](../../lib/screens/pg/character_sheet/bio_tab.dart)), two sections are single free-text blobs:

- **"Competenze e Lingue"** — one `SheetTextField` backed by `Character.profsAndLanguages` (a `String`).
- **"Caratteristiche e Talenti"** — one `SheetTextField` backed by `Character.featuresAndTraits` (a `String`).

A single multiline box is too reductive. A character has *several distinct* languages and *several distinct* features/talents, each a separate item with its own meaning. Cramming them into one blob loses structure: no per-item editing, no clear boundary between one talent's name and its description, no clean way to add or remove a single entry.

## Solution

Replace each blob with a list of individual entries, keeping the two blocks distinct.

- **Linguaggi**: a list of languages. Each entry is a single text box holding one language. The block is renamed from "Competenze e Lingue" to **"Linguaggi"** — it now covers languages only. The former *proficiencies* concept is dropped from this tab; any legacy proficiency text folds into language entries on migration and the user cleans it up by hand.
- **Caratteristiche e Talenti**: a list of features. Each entry has a **title** (name of the stat/feature) and a **description**.

Each block gets an "aggiungi" button to append an empty entry and a remove control per entry. No reordering — order is insertion order.

Storage reuses the two existing TEXT columns; their contents change from a plain string to a JSON-encoded list. No schema migration step is added. Legacy plain-text values are detected at load and converted.

## User Stories

1. As a player, I want to add each language as its own box, so that my languages are a clean list instead of one crammed paragraph.
2. As a player, I want to remove a single language without editing around it in a blob.
3. As a player, I want each feature/talent to have a title and a separate description, so that its name and its explanation are clearly distinct.
4. As a player, I want to add and remove individual features, so that managing them is one-at-a-time, not text surgery.
5. As an existing user upgrading, I want my current "Competenze e Lingue" text preserved as language entries (one per line), so that nothing I typed is lost.
6. As an existing user upgrading, I want my current "Caratteristiche e Talenti" text preserved as feature entries (one per line, in the description), so that nothing I typed is lost — I retitle by hand.
7. As a player, I want blank entries I never filled in to disappear on save, so that reload doesn't show ghost rows.
8. As a developer, I want no new DB columns or migration step, so that the change stays confined to the Dart representation and the tab UI.

## Implementation Decisions

- **New model class `CharacterFeature`** in [character.dart](../../lib/models/character.dart): `{ String title; String description; }` with hand-written `toJson`/`fromJson`, mirroring `EquipmentItem`.
- **Field replacements on `Character`**:
  - `String profsAndLanguages` → `List<String> languages`.
  - `String featuresAndTraits` → `List<CharacterFeature> features`.
  - Fields renamed to match new semantics (not kept under the old misleading names).
- **Reuse existing columns.** `profs_and_languages` and `features_and_traits` stay as the TEXT columns; they now hold JSON. No new columns, no `MigrationStep`. The `profs_and_languages` column name is now slightly misleading (languages only) — accepted, harmless.
- **Load-time detect + convert in `fromMap`.** For each of the two values:
  - If the string starts with `[`, parse it as a JSON list (the new format).
  - Otherwise it is legacy plain text: split on newlines.
    - Languages: each non-empty line becomes one language string.
    - Features: each non-empty line becomes a `CharacterFeature` with `description = line` and `title = ''` (user retitles by hand).
  - Empty/absent value → empty list.
- **Serialize + prune in `toMap`.** JSON-encode both lists. Before encoding, drop fully-empty entries: an empty/whitespace language string; a feature whose title and description are both empty/whitespace.
- **UI — Linguaggi block** ([bio_tab.dart](../../lib/screens/pg/character_sheet/bio_tab.dart)): section header "Linguaggi", then a vertical list of rows — each row a full-width text box + a remove icon — then an "aggiungi" button.
- **UI — Caratteristiche e Talenti block**: section header, then a vertical list of **bordered cards**, one per entry — single-line title box on top, multiline description below, remove icon top-right — then an "aggiungi" button.
- **Add/remove only, no reorder.** Add appends an empty entry; remove deletes that entry.
- **Controller lifecycle.** Per-entry `TextEditingController`s are created/disposed as entries are added/removed, following existing controller-management style in the tab.

## Testing Decisions

Unit tests at the model layer (`test/models/`), covering the risky conversion/serialization logic — no widget tests.

- `fromMap` legacy conversion: a plain multi-line `profs_and_languages` → `languages` list (one per line, blanks skipped); a plain multi-line `features_and_traits` → `features` list (description = line, title empty).
- `fromMap` new-format: a JSON-encoded list value round-trips back to the same list.
- `toMap` prune: fully-empty entries (empty language; feature with empty title+description) are dropped from the encoded output; partially-filled entries survive.
- Full round-trip: `Character.fromMap(c.toMap())` preserves populated `languages` and `features`.

## Out of Scope

- Reordering entries (drag handles).
- A separate "Competenze" block — proficiencies are dropped from this tab, not relocated.
- Widget/UI tests for add/remove.
- Any schema migration step or new columns.
- Displaying these fields anywhere other than the Bio tab (no other consumer exists today).
