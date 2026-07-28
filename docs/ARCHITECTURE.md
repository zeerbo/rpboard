# Architecture & Onboarding

Onboarding map of **RPBoard** as it exists today. Companion app for tabletop RPG groups: a Dungeon Master builds campaigns and runs live sessions; players view/edit their own character sheets. Single-user, local, offline — SQLite on device, no sync or multiplayer.

For domain vocabulary see [CONTEXT.md](../CONTEXT.md). For the one architectural decision recorded so far see [docs/adr/0001-typed-component-data.md](adr/0001-typed-component-data.md). **This file describes the code; CONTEXT.md defines the words.**

> All user-facing strings are hardcoded Italian. There is no localization layer.

---

## Tech stack

| Concern | Choice | Version |
| --- | --- | --- |
| Framework | Flutter / Dart | Dart SDK `^3.12.2` |
| State management | `flutter_riverpod` | `^2.6.1` |
| Routing | `go_router` | `^14.6.2` |
| Database | `sqflite` + `sqflite_common_ffi` | `^2.4.2` / `^2.3.4+2` |
| Paths | `path_provider`, `path` | — |
| IDs | `uuid` | `^4.5.1` |
| Lints | `flutter_lints` | `^6.0.0` |

No JSON codegen (`freezed` / `json_serializable`). Every model hand-rolls `fromMap`/`toMap` — deliberate, per ADR-0001.

`sqflite_common_ffi` is what makes the app run on desktop (Windows/Linux/macOS). It is initialized in [lib/main.dart](../lib/main.dart) for non-web desktop platforms.

---

## The domain tree

Two independent top-level entities. One owning-hierarchy for Master Mode, one flat entity for PG Mode.

```
Master Mode                          PG Mode
───────────                          ───────
Campaign                             Character   (standalone)
  └─ Chapter                           ├─ Attack
       └─ SessionScreen                ├─ SpellSlot
            └─ SessionComponent        ├─ Spell
                 (data: JSON map)      └─ InventoryItem
```

Ownership is `ON DELETE CASCADE` all the way down: deleting a Campaign wipes its Chapters, their SessionScreens, and their SessionComponents. Character is **not** part of this tree — it is PG Mode's own root entity in its own table.

The route paths in [lib/app.dart](../lib/app.dart) mirror this ownership chain exactly:
`/campaigns/:campaignId/chapters/:chapterId/screens/:screenId/edit` (and `/play`).

---

## Layer layout (`lib/`)

```
lib/
├── main.dart                  Entry: DB-factory init for desktop, runApp(ProviderScope(...))
├── app.dart                   MaterialApp.router + full go_router table (PG + Master sections)
├── core/
│   ├── database/db.dart       AppDatabase singleton: schema + ALL CRUD for 5 tables
│   └── theme/app_theme.dart   Dark-only ThemeData + color constants
├── models/                    Plain Dart data classes, hand-rolled JSON
├── providers/                 Riverpod AsyncNotifiers (one per collection)
└── screens/                   UI, split into pg/ and master/
```

There is **no** `core/routing`, `core/utils`, or shared JSON helper. Routing lives inline in `app.dart`; serialization lives per-model.

---

## Models (`lib/models/`)

| Class | File | Glossary term | Notes |
| --- | --- | --- | --- |
| `Campaign` | `campaign.dart` | Campaign | `id, name, description, setting, createdAt, updatedAt` |
| `Chapter` | `chapter.dart` | Chapter | `id, campaignId, title, summary, order` |
| `SessionScreen` | `session_screen.dart` | SessionScreen | `id, chapterId, title, order` (no description field) |
| `SessionComponent` | `component.dart:23` | SessionComponent | `id, screenId, type (ComponentType), order, data (Map<String,dynamic>)` |
| `Character` | `character.dart:169` | Character (PG) | Large flat sheet: identity, ability scores + derived mods, combat, proficiencies, currency, spellcasting, notes |

**Character value objects** (same file): `Attack` (`character.dart:3`), `SpellSlot` (`:31`), `Spell` (`:51`), `InventoryItem` (`:99`), plus 5e-style skill/ability constants `kSkills`/`kSkillAbility` (`:127`).

### The SessionComponent content model — READ THIS

This is the single most confusing part of the codebase. There are **two parallel representations** of a component's content, and only one is live.

**1. Production path (what actually runs):**
- `SessionComponent.data` is a raw `Map<String, dynamic>` decoded from a JSON column ([component.dart:28](../lib/models/component.dart)).
- Component kind is an enum `ComponentType { narrativeText, npcStatBlock, initiativeTracker, customTable, image }` ([component.dart:3](../lib/models/component.dart)).
- Widgets read/write content by string key — `component.data['title']` — with no compile-time safety.
- New components are seeded via `ComponentDefaults` (`component.dart:360`) which returns a default `data` map per `ComponentType`.

**2. Typed path (ADR-0001, defined but DEAD):**
- A `sealed class ComponentData` hierarchy exists ([component.dart:75](../lib/models/component.dart)): `NarrativeTextData`, `NpcStatBlockData`, `InitiativeTrackerData`, `CustomTableData`, `ImageData`, `UnknownComponentData`.
- It is **additive and unreferenced** — the file's own comment says so (`component.dart:68`). Only `test/models/component_test.dart` uses it. No screen, provider, or widget touches it.

**Consequence for new contributors:** [ADR-0001](adr/0001-typed-component-data.md) reads as if `ComponentData` replaced the untyped map. It did **not** get wired up. If you read the ADR first you will expect typed dispatch that does not exist in the running app. Treat the sealed hierarchy as an intended-but-unfinished migration, not the current design. See [Known gaps](#known-gaps--drift).

---

## State management (`lib/providers/`)

Riverpod `AsyncNotifier`s, one per collection. All follow the same shape: `build()` loads from `AppDatabase.instance`; `add`/`save`/`delete` mutate then `ref.invalidateSelf()`.

| Provider | Type | Keyed by | Manages |
| --- | --- | --- | --- |
| `campaignListProvider` | `AsyncNotifier<List<Campaign>>` | — | All campaigns |
| `chapterListProvider` | `FamilyAsyncNotifier<…, String>` | `campaignId` | A campaign's chapters |
| `screenListProvider` | `FamilyAsyncNotifier<…, String>` | `chapterId` | A chapter's screens |
| `componentListProvider` | `FamilyAsyncNotifier<…, String>` | `screenId` | A screen's components |
| `characterListProvider` | `AsyncNotifier<List<Character>>` | — | All characters |

**Informal pattern to know:** screens fetch single items **directly** from `AppDatabase.instance` (e.g. `CampaignScreen._loadCampaign`, `chapter_screen.dart:36`, `session_edit_screen.dart:41`) and use the provider only for the *list* and for *mutations*. There are no single-item providers.

---

## Screens (`lib/screens/`)

| Screen | File | Mode | Purpose |
| --- | --- | --- | --- |
| `HomeScreen` | `home_screen.dart` | entry | Chooser: "Modalità Giocatore" vs "Modalità Master" |
| `CharacterListScreen` | `pg/character_list_screen.dart` | PG | List/create/delete characters |
| `CharacterSheetScreen` | `pg/character_sheet_screen.dart` | PG | 7-tab sheet editor with debounced autosave |
| `CampaignListScreen` | `master/campaign_list_screen.dart` | Master | List/create/delete campaigns |
| `CampaignScreen` | `master/campaign_screen.dart` | Master | Edit campaign + reorder its chapters |
| `ChapterScreen` | `master/chapter_screen.dart` | Master | Edit chapter + reorder its screens; launch play mode |
| `SessionEditScreen` | `master/session/session_edit_screen.dart` | Master | Build one SessionScreen: add/reorder/delete components |
| `SessionPlayScreen` | `master/session/session_play_screen.dart` | Master | Live "present to table": paginate screens, fullscreen |

### Component-rendering widgets (`master/session/components/`)

Each takes a `SessionComponent` + `isEditMode` + `onUpdate` callback, and reads/writes `component.data[...]` directly.

- `NarrativeWidget` — title + content text block
- `NpcStatBlockWidget` — full NPC/monster stat card + edit dialog
- `InitiativeTrackerWidget` — combatant list, round/turn advance, HP, dice roll

**Note the asymmetry:** `customTable` and `image` have **no dedicated widget file**. They are rendered as private inline classes, duplicated across edit and play:
- `_CustomTableWidget` / `_ImageWidget` in `session_edit_screen.dart:245`
- `_TableView` / `_ImageView` in `session_play_screen.dart:205`

---

## Persistence (`lib/core/database/db.dart`)

One class, `AppDatabase` (singleton), is the **entire** persistence layer — schema, DAO, and repository behavior combined. No separate DAO classes.

- DB file: `<ApplicationDocumentsDirectory>/rpboard/rpboard.db`
- Schema **version 1**, single `onCreate`. **No `onUpgrade` migration path exists yet** — the first schema change must add one.
- Tables: `characters`, `campaigns`, `chapters` (FK→campaigns), `session_screens` (FK→chapters), `components` (FK→session_screens). All FKs `ON DELETE CASCADE`.
- `components.type` stores `ComponentType.name` (e.g. `'narrativeText'`); `components.data` stores JSON text. Per ADR-0001 these strings are a **frozen contract** — already persisted in every user's DB, so renaming a kind requires a migration.

---

## Known gaps & drift

Faithful record of current state, for anyone about to add features.

1. **`ComponentData` sealed hierarchy is dead code.** Defined ([component.dart:75](../lib/models/component.dart)), tested, but wired into nothing. Production uses the untyped `data` map. ADR-0001 describes the intended end state, not the shipped one.

2. **`ComponentType` enum duplicates `ComponentData.dbKey`.** ADR-0001 explicitly *rejected* keeping both (dual representation, two switches to sync). Both currently exist — the ADR's rejected option is what's on disk, because the migration stopped halfway.

3. ~~**"Scena" (Scene) is the UI label for SessionScreen** — a term CONTEXT.md explicitly says to avoid.~~ **Resolved (C8):** CONTEXT.md now registers "Scena" as the user-facing Italian label of `SessionScreen`. The copy stays as it is (`chapter_screen.dart:43,117`, `session_edit_screen.dart:69,110`, `session_play_screen.dart:133`); what stays banned is `Scene`/`Scena` as a code or domain identifier.

4. **`customTable` / `image` rendering is duplicated inline** across edit and play screens instead of sharing a widget like the other three kinds.

5. **No schema migration path.** `AppDatabase` is at version 1 with no `onUpgrade`.

6. **`*Widget` naming.** The rendering classes (`NarrativeWidget`, …) are literal Flutter `Widget`s (fine), but CONTEXT.md warns against conflating them with the `SessionComponent`/`ComponentData` *domain* concept. Keep the two senses separate when discussing.

---

## Where to start reading

1. [CONTEXT.md](../CONTEXT.md) — the vocabulary.
2. [lib/app.dart](../lib/app.dart) — routes = the whole navigable surface.
3. [lib/core/database/db.dart](../lib/core/database/db.dart) — schema = the whole data model.
4. [lib/models/component.dart](../lib/models/component.dart) — the one genuinely tricky file (read the "two representations" note above first).
