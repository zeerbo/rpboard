# 02 — Single ComponentView dispatch point

**What to build:** Collapse the edit screen's and the play screen's two separate kind switches into one. A `ComponentView` widget takes a component's `ComponentData`, `isEditMode`, and `onUpdate`, and performs a single exhaustive `switch` over the sealed `ComponentData` to pick the right per-kind widget among all five (narrative text, NPC stat block, initiative tracker, custom table, image) plus the placeholder for an unrecognized kind. The edit screen's component card and the play screen's component renderer both call `ComponentView` for their content instead of switching on kind themselves — one dispatch point instead of two, so a developer adding a sixth kind updates a single site instead of remembering to keep two switches in sync. `ComponentView` renders content only: the edit screen keeps its own card, drag handle, kind label, and delete button wrapped around it, and the play screen keeps its own surrounding layout; nothing about either screen's chrome changes. `onUpdate` keeps flowing through unchanged for both modes, so the initiative tracker can still save state while running a live session. No behavior changes for the DM: narrative text, NPC stat block, and initiative tracker keep behaving exactly as before, and the custom table and image components keep the consistent look ticket 01 already gave them — this ticket only moves where the kind decision is made, not what gets rendered.

**Blocked by:** 01 — CustomTableData and ImageData get their own widgets. `ComponentView`'s switch needs all five per-kind widgets to exist before it can dispatch to them.

**Status:** done

- [x] A new `ComponentView` `StatelessWidget` exists under `master/session/components/`, with a `(component, isEditMode, onUpdate)` constructor
- [x] `ComponentView` performs one exhaustive `switch` over the sealed `ComponentData`, selecting the narrative, NPC stat block, initiative tracker, custom table, or image widget, plus a case for the unrecognized-kind placeholder that the typed cutover introduced
- [x] The edit screen's component card no longer contains its own switch over component kind; it calls `ComponentView` with `isEditMode: true` for its content, keeping its card, drag handle, kind label, and delete button around it unchanged
- [x] The play screen's component renderer no longer contains its own switch over component kind; it calls `ComponentView` with `isEditMode: false` for its content, keeping its own surrounding layout unchanged
- [x] A repo-wide search for a switch over component kind or `ComponentData` outside of `ComponentView` itself returns nothing under `master/session/`
- [x] `onUpdate` is threaded through unchanged at both call sites; a widget test confirms the initiative tracker (or another interactive kind) can still trigger `onUpdate` when reached through `ComponentView` with `isEditMode: false`
- [x] A new widget test pumps `ComponentView` once for each of the five known `ComponentData` kinds plus the unrecognized-kind case, asserting the matching per-kind widget (or placeholder) renders, and that edit affordances follow `isEditMode` where the underlying widget has any
- [x] Manual check: a SessionScreen built in Edit Mode with all five kinds renders identically in Play Mode as it did before this ticket, for every kind
- [x] `flutter analyze` is clean; `flutter test` is green
