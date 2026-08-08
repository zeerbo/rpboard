Status: ready-for-agent

# One renderer for SessionComponent

Implements architecture-review candidate **C5** (`docs/architecture-review.html#c5`). Builds directly on [ADR-0001](../../docs/adr/0001-typed-component-data.md) and the typed cutover it drove ([.scratch/typed-component-data/PRD.md](../typed-component-data/PRD.md)); no new ADR is needed, since this follows from a decision already recorded.

## Problem Statement

A SessionScreen is built from five kinds of SessionComponent: narrative text, an NPC stat block, an initiative tracker, a custom table, and an image. Three of those five already share a single widget file under `master/session/components/`, parameterised by `isEditMode` so the same code renders both the edit screen and the live-play screen. The other two — custom table and image — never got that treatment. They exist only as private classes duplicated between the two screens: `_CustomTableWidget`/`_ImageWidget` inside `session_edit_screen.dart`, and `_TableView`/`_ImageView` inside `session_play_screen.dart`. Together that's roughly 180 lines that say the same thing twice, and any fix or field added to a table or image component has to be made — and kept in sync — in both places.

The kind dispatch has the same problem one level up: `session_edit_screen.dart`'s `_ComponentCard` and `session_play_screen.dart`'s `_PlayComponent` each carry their own switch over the component's kind, deciding which widget to build. Today those two switches happen to agree, but nothing enforces that; a developer adding a sixth kind has to remember to update both.

C1 (the typed cutover) replaces `ComponentType` with the sealed `ComponentData` hierarchy and turns both of those switches into compiler-exhaustive `switch (data)` statements — so a missing case is now a build error instead of a silent gap. But C1 deliberately stops there: it leaves the two switches as two separate switches, and leaves the table/image classes exactly as duplicated as before. This PRD is the change that removes that remaining duplication, once C1's typed dispatch exists to build it on.

## Solution

Give `customTable` and `image` a dedicated widget file each, symmetric with the three that already exist, so all five kinds live under `master/session/components/` the same way. Then collapse the two separate kind switches into one: a `ComponentView` widget that takes a component's data, `isEditMode`, and `onUpdate`, and performs a single exhaustive switch over the sealed `ComponentData` to pick the right per-kind widget. The edit screen and the play screen both call `ComponentView` instead of each carrying their own switch — one dispatch point instead of two.

Each per-kind widget keeps `isEditMode` doing exactly what it already does for narrative/NPC/initiative: toggling edit affordances and density, not the underlying structure. For table and image this means writing the layout once instead of once-per-screen, with `isEditMode` switching visible differences (configure/edit buttons and dialogs, image preview height, font sizes) rather than the whole widget being copy-pasted with small edits. The screens keep everything that isn't rendering — the edit screen's `Card`, drag handle, kind label and delete button, and the play screen's own layout — around whatever `ComponentView` renders.

No behavior changes for the DM beyond the one intended: the custom table and image components get a consistent look between building a SessionScreen and running it live. The other three kinds are untouched.

## User Stories

1. As a developer adding a `customTable` component, I want its rendering to live in one file under `master/session/components/`, so that I edit its layout once instead of finding and updating two near-identical private classes.
2. As a developer adding an `image` component, I want the same: one file, not a private class duplicated in two screens.
3. As a developer who has just finished C1, I want the typed `ComponentData` switch dispatch it introduced to be the thing this work builds on, so that C5 doesn't have to re-derive typed dispatch from scratch.
4. As a developer working on the edit screen or the play screen, I want a single `ComponentView` widget to be the only place that switches on component kind, so that adding a sixth kind is one dispatch site to update, not two.
5. As a developer reading `session_edit_screen.dart`, I want `_ComponentCard` to delegate to `ComponentView` for content, so that the card's chrome (drag handle, kind label, delete button) stays visually separate from what a specific kind renders.
6. As a developer reading `session_play_screen.dart`, I want `_PlayComponent` to delegate to `ComponentView` the same way, so that edit and play visibly share the same rendering decision instead of coincidentally agreeing.
7. As a developer, I want `ComponentView` to be a real widget in the tree — not a top-level function returning a widget — so that it participates normally in `const` construction, keying, and rebuild scoping like every other widget.
8. As a developer, I want the sealed `ComponentData` subclasses to stay pure Dart with no Flutter dependency, so that `lib/models/` remains testable without pumping a widget tree.
9. As a developer building the table widget, I want payload parsing, the table itself, the empty-state placeholder, and the caption to be written once per kind, with `isEditMode` only toggling the edit affordances and density around that shared core, so that fixing a rendering bug doesn't mean fixing it in two layouts.
10. As a developer building the image widget, I want the same one-structure-two-modes shape, so that the edit-mode preview and the play-mode display come from the same code path.
11. As a developer, I want `onUpdate` to keep flowing through `ComponentView` in both edit and play modes, so that interactive kinds like the initiative tracker can still save state while running a live session.
12. As a developer, I want the two new component widgets to follow the same `(component, isEditMode, onUpdate)` constructor shape as the three existing ones, so that all five are interchangeable from the dispatcher's point of view.
13. As a DM building a SessionScreen, I want a custom table I configure in edit mode to look and behave consistently when I switch to play mode, so that what I prepared is recognizably what I present.
14. As a DM building a SessionScreen, I want an image component's caption and layout to be consistent between edit and play, so that there are no surprises when I go live.
15. As a DM running a live session, I want narrative text, NPC stat blocks, and the initiative tracker to behave exactly as they did before this change, so that this refactor doesn't disturb anything I already rely on.
16. As a developer picking up C3 (reorder) after this lands, I want the edit screen's component list to be unaffected by this change beyond the content-rendering delegation, so that reordering work doesn't have to account for a rendering refactor happening at the same time.

## Implementation Decisions

- **Sequencing and boundary with C1 (critical).** C1 does the typed cutover: `SessionComponent` carries a `ComponentData`, and the two render switches in the edit and play screens become compiler-exhaustive `switch (data)` statements over the sealed hierarchy. C1 deliberately leaves both switches where they are and leaves the table/image classes duplicated — collapsing them is explicitly out of C1's scope. C5 lands after C1 and assumes typed `ComponentData` dispatch already exists; it does not redo or touch the typed-cutover work itself. Rejected: folding C5 into C1's cutover issue (one diff spanning models, two screens, and five widgets is too large a unit of change); doing C5 first, against the old `ComponentType` enum (the renderer would have to be rewritten a second time once C1 landed).
- **Two new files, symmetric with the existing three.** `customTable` and `image` each get their own widget file under `master/session/components/`, alongside `narrative_widget.dart`, `npc_stat_block_widget.dart`, and `initiative_tracker_widget.dart`. Each takes the same `(component/data, isEditMode, onUpdate)` shape as its siblings.
- **One dispatch point: `ComponentView`.** A `ComponentView` `StatelessWidget` takes `(component, isEditMode, onUpdate)` and performs the single exhaustive switch over the sealed `ComponentData` to select the per-kind widget. Both the edit screen and the play screen call it — one interface, two call sites, replacing the two separate switches (`_ComponentCard`'s and `_PlayComponent`'s).
- **Rejected: a top-level `renderComponent(...)` function.** It isn't a tree node — no `const` constructor, no `Key`, and any rebuild triggered above it falls through to the parent instead of being scoped to the component. A `StatelessWidget` gives normal Flutter rebuild behavior for free.
- **Rejected: `render()` on the `ComponentData` subclasses.** Putting rendering on the model would drag Flutter into `lib/models/`, which is pure Dart today and must stay testable without Flutter (see Known gap #6 in `docs/ARCHITECTURE.md` on keeping the domain concept and the Flutter `Widget` sense separate).
- **Chrome stays where it belongs.** The edit screen keeps its `Card`, drag handle, kind label, and delete button wrapped around `ComponentView`. The play screen keeps its own surrounding layout. `ComponentView` and the per-kind widgets it dispatches to render content only — no card, no header, no delete affordance.
- **Layout unification for table and image: one parametric structure per kind.** `isEditMode` controls exactly two things — the edit affordances (the configure/edit buttons and their dialogs, edit-mode only) and density (image preview height, font sizes). Payload parsing, the table itself, the empty-state placeholder, and the caption exist once per kind, not once per screen.
- **Rejected: preserving both current layouts verbatim behind an `if (isEditMode)`.** That only moves the duplication inside the file instead of removing it.
- **Rejected: making edit look exactly like play.** A full-height image per card would make the edit-mode component list unwieldy; the two modes are allowed to differ in density, just not in structure or code path.
- **`onUpdate` keeps flowing in both modes.** The initiative tracker is interactive during play (advancing turns, tracking HP, rolling dice) and must still be able to save; `ComponentView` and every per-kind widget accept and forward `onUpdate` regardless of `isEditMode`.
- **No behavior change for the DM beyond the intended one.** Table and image gain a consistent look across edit and play. Nothing changes for narrative text, NPC stat block, or initiative tracker.

## Testing Decisions

- **First widget tests in the repo.** Every prior test (`test/models/component_test.dart`, the provider tests) is pure Dart with no widget pump. The component widgets and `ComponentView` are the first tests that pump a widget tree, because rendering is the thing under test here.
- **Keep them minimal and behavioral.** For each of the five kinds: pumping `ComponentView` with that kind's `ComponentData` renders that kind's widget, and the edit affordances (configure/edit buttons) are present when `isEditMode` is true and absent when `isEditMode` is false.
- **Payload shape, defaults, and JSON round-trip are out of scope here.** They're pure-Dart model concerns and belong to C1's sealed `ComponentData` tests (prior art: `test/models/component_test.dart`), not to this widget-test surface.
- **No golden/screenshot tests.** Do not assert on layout constants, paddings, or colors — those are implementation details, not behavior.
- **Prior art for the pure-Dart discipline that this widget-test layer sits alongside:** `test/models/component_test.dart` and `test/providers/*_test.dart`.

## Out of Scope

- The typed cutover itself and removing the `ComponentType` enum — that's C1, a hard dependency of this work, not part of it.
- Adding a sixth kind of SessionComponent.
- An image picker, or any change to how image paths are stored or resolved.
- The edit screen's card chrome (drag handle, kind label, delete button) — it stays exactly where it is, just wrapping `ComponentView` instead of a private switch.
- Reordering components — that's C3.
- Any schema or persistence change — this is a rendering-layer refactor only; `SessionComponent`/`ComponentData` and the `components` table are untouched.
- Golden/screenshot testing of the rendered widgets.

## Further Notes

- Domain vocabulary above (`SessionComponent`, `ComponentData`, SessionScreen, Master Mode) matches `CONTEXT.md`. Per CONTEXT.md, "Widget" names the Flutter rendering layer, not the domain concept — `ComponentView` and the per-kind widgets are Flutter `Widget`s in that Flutter sense, rendering a `SessionComponent`'s `ComponentData`, not a redefinition of the domain term.
- Sequencing for the review as a whole: C1 → C5 → C3 → C4 → C6 → C7. C5 is next after C1 specifically because it depends on C1's typed dispatch and nothing else in the sequence does.
- Expected blast radius: two new files under `master/session/components/`, one new `ComponentView` file, and edits to `session_edit_screen.dart`'s `_ComponentCard` and `session_play_screen.dart`'s `_PlayComponent` to delegate instead of switching themselves. The private `_CustomTableWidget`, `_ImageWidget`, `_TableView`, and `_ImageView` classes are deleted once their content moves into the two new widget files.
