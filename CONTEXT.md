# RPBoard

Companion app for tabletop RPG groups: a Dungeon Master builds campaigns and runs sessions from prepared screens; players view their own character sheets. Single-user local app (SQLite on device), no sync/multiplayer.

## Language

**Campaign**:
A DM's ongoing game, the top-level container. Owns Chapters.
_Avoid_: Story, adventure

**Chapter**:
A named subdivision of a Campaign (e.g. an arc or in-game location), ordered within the Campaign. Owns SessionScreens.
_Avoid_: Act, part

**SessionScreen**:
One prepared "page" a DM presents during a live session, ordered within a Chapter. Owns SessionComponents.
_User-facing label_: **"Scena"** — the Italian word the DM reads throughout Master Mode. `SessionScreen` is the domain and code identifier; "Scena" is its label in the interface, and the two are allowed to differ.
_Avoid_: Slide; `Scene`/`Scena` as a code or domain identifier

**SessionComponent**:
A single positioned piece of content on a SessionScreen (e.g. narrative text, an NPC stat block, an initiative tracker). Holds a `ComponentData` payload plus screen-level metadata (id, order).
_Avoid_: Widget (that's the Flutter rendering layer, not the domain concept), block

**ComponentData**:
The typed payload carried by a SessionComponent — one concrete shape per kind of content (narrative text, NPC stat block, initiative tracker, custom table, image, or an unrecognized/unknown kind). Persisted as JSON but manipulated as a typed Dart object, never a raw map. Each kind is identified by a `dbKey`, the frozen string written to the database. See [ADR-0001](docs/adr/0001-typed-component-data.md).
_Avoid_: Data blob, payload map

**Character**:
A single player character sheet — PG Mode's root entity, owned by no Campaign. It is where the 5e-style rules derived from a sheet live (ability modifiers, proficiency bonus, skill and saving-throw bonuses, spell save DC and attack bonus, spell slots, death saves): a rule that can be computed from a Character belongs to the Character, not to the screen showing it.
_Avoid_: PG (that's the mode), sheet, hero, player (the person, not the character)

**Ordered**:
The contract shared by the entities whose position within their parent the DM controls by dragging — Chapter, SessionScreen, SessionComponent. Each carries an id and a position, and the positions of a parent's children are always a dense sequence starting at zero. Campaign is not Ordered: campaigns are listed by when they were last updated. See [ADR-0003](docs/adr/0003-atomic-reorder.md).
_Avoid_: Sort key, index, rank, position field

**Database**:
The persistence seam — an interface declaring the app's CRUD operations over its aggregates (Character, Campaign, Chapter, SessionScreen, SessionComponent). Callers reach it through `databaseProvider`, never a static global. Two adapters implement it: `SqfliteDatabase` (the real on-device SQLite store) and `InMemoryDatabase` (a behavioral fake used only in tests). See [ADR-0002](docs/adr/0002-database-seam.md).
_Avoid_: DB layer, DAO, repository (the seam is one interface, not per-aggregate repositories)

**Migration**:
One step of the ladder that takes an already-installed Database from one schema version to the next. The ladder is ordered and append-only: a released step is never edited, and creating a database from scratch means running every step from zero, so a fresh install and an upgraded install end up identical. See [ADR-0005](docs/adr/0005-schema-migrations.md).
_Avoid_: Patch, upgrade script, seed

**PG Mode**:
The player-facing side of the app — viewing/editing one's own Character sheet. ("PG" = *Personaggio Giocante*, Italian for player character.)
_Avoid_: Player mode

**Master Mode**:
The DM-facing side of the app — building Campaigns/Chapters/SessionScreens and running live sessions.
_Avoid_: DM mode, GM mode

**Edit Mode / Play Mode**:
The two modes in which a SessionScreen is presented inside Master Mode: Edit Mode is preparation (adding, reordering and configuring SessionComponents), Play Mode is presenting the prepared screens at the table. Every kind of SessionComponent renders in both; the mode decides which affordances are offered, never which component exists.
_Avoid_: Preview, presentation mode, read-only mode

## Where the decisions live

This file defines the words. The agreed refactoring work from the [architecture review](docs/architecture-review.html) is specified elsewhere — one PRD per candidate, plus an ADR where the decision is hard to reverse. Planned order: C1 → C5 → C3 → C4 → C6 → C7.

| | Candidate | Spec | Decision record |
| --- | --- | --- | --- |
| C1 | Typed `ComponentData` end-to-end | [PRD](.scratch/typed-component-data/PRD.md) | [ADR-0001](docs/adr/0001-typed-component-data.md) |
| C2 | Database seam — **done** | [PRD](.scratch/database-seam/PRD.md) | [ADR-0002](docs/adr/0002-database-seam.md) |
| C3 | Atomic reordering | [PRD](.scratch/atomic-reorder/PRD.md) | [ADR-0003](docs/adr/0003-atomic-reorder.md) |
| C4 | One source per entity | [PRD](.scratch/single-item-providers/PRD.md) | [ADR-0004](docs/adr/0004-single-item-providers.md) |
| C5 | One renderer per SessionComponent | [PRD](.scratch/unified-component-renderer/PRD.md) | follows ADR-0001 |
| C6 | Schema migrations | [PRD](.scratch/schema-migrations/PRD.md) | [ADR-0005](docs/adr/0005-schema-migrations.md) |
| C7 | Decomposing the Character sheet | [PRD](.scratch/character-sheet-decomposition/PRD.md) | follows ADR-0004 |
| C8 | "Scena" as vocabulary | — | recorded above, under SessionScreen |
