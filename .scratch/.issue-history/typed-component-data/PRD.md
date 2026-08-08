Status: ready-for-agent

# Typed ComponentData for SessionComponent

See [ADR-0001](../../docs/adr/0001-typed-component-data.md) for the accepted decision this PRD implements, including the amended Consequence #2.

## Problem Statement

Today a `SessionComponent`'s content is a raw `Map<String, dynamic>` decoded from JSON. Anyone building or editing a SessionScreen widget reaches into that map by string key (`data['title']`, `data['combatants']`, ...) with no compile-time check that the key exists or holds the right shape. A typo in a key silently produces a blank field instead of an error.

Worse, the shape of each kind is written down three separate times — once in the defaults factory, once in `fromJson`, once in `toJson` — and dispatched from five separate switches. Two parallel representations of the same payload coexist: the untyped map is the live one, while a typed sealed `ComponentData` hierarchy sits in the model as dead code that nothing references. Adding a sixth kind of SessionComponent means remembering all five switch sites unaided; the compiler helps with none of them.

Separately, if a DM opens a save file containing a component kind their current app build doesn't recognize (after a downgrade, or a save prepared on a newer build), the component silently renders as a blank narrative-text box. It looks exactly like a normal, empty narrative component — nothing indicates that the original content still exists and wasn't lost. The same silent-blank outcome occurs if a component's persisted JSON is corrupt.

## Solution

Retire the untyped map and make the sealed `ComponentData` hierarchy the live, sole representation of a SessionComponent's payload. `SessionComponent` drops its `ComponentType` field entirely — a component's kind is read from its payload's `dbKey`, so the two can never disagree. The `ComponentType` enum, its label extension, and the defaults factory are deleted.

Every field access becomes compiler-checked, and every dispatch site becomes an exhaustive `switch` over the sealed type, so adding a sixth kind of SessionComponent produces build errors at each site until it is handled — the safety the enum never provided.

Unrecognized or unreadable payloads no longer masquerade as empty narrative text. They deserialize into `UnknownComponentData`, which keeps the original persisted kind string and raw JSON intact and renders as a visibly labeled "unsupported component" placeholder — so a DM immediately understands the content still exists, just isn't displayable in this build, and re-saving the SessionScreen won't destroy it.

## User Stories

1. As a developer adding a new field to an NPC stat block payload, I want the compiler to flag every place that constructs or reads the old shape, so that I can't ship a build where a widget silently reads `null` from a renamed key.
2. As a developer implementing a sixth kind of SessionComponent, I want the compiler to flag every `switch` over `ComponentData` that doesn't yet handle it, so that I can't forget a dispatch site.
3. As a developer reading the narrative component's widget, I want `data.title` instead of `data['title'] as String? ?? ''`, so that the field's type and presence are guaranteed by the compiler, not by convention.
4. As a developer, I want a SessionComponent to have exactly one representation of "what kind is this", so that a kind field and a payload can never drift apart.
5. As a developer adding a sixth kind, I want to declare its persisted identity, its empty-instance factory, and its parser in a single registry entry, so that I am not maintaining two or three parallel lists keyed by the same string.
6. As a developer, I want the persisted kind string for each subclass to be written as one literal that the registry references, so that a registry entry cannot disagree with the subclass it names.
7. As a developer, I want the icon and label for a kind resolved by an exhaustive switch rather than a string-keyed lookup table, so that a missing entry is a build error rather than a blank menu row discovered at runtime.
8. As a developer, I want icon and label resolution to stay in the UI layer, so that the model layer keeps no dependency on Flutter or `IconData`.
9. As a developer creating a new component from the "add" menu, I want its seed values (a friendly NPC name, a default challenge rating, a sensible speed) to come from a factory written for that purpose, so that a newly added NPC isn't a wall of empty strings.
10. As a developer, I want that seed factory kept separate from the tolerant defaults used when parsing a payload with missing keys, so that loosening a parser default never silently changes what a freshly created component looks like.
11. As a DM opening a SessionScreen prepared on a newer build of the app, I want an unrecognized component to show a clearly labeled "unsupported component" placeholder naming the kind, so that I know my content still exists rather than assuming it's gone.
12. As a DM, I want that placeholder to preserve the original data untouched and offer no editor, so that re-saving the SessionScreen from an older build can't destroy the newer content.
13. As a DM whose component payload was corrupted by an interrupted write, I want the SessionScreen to still open with that one component shown as a placeholder, so that a single bad row doesn't make the whole screen unopenable.
14. As a DM, I want that corrupt component's original bytes preserved rather than reset, so that the data remains recoverable outside the app.
15. As a DM upgrading the app across this refactor, I want every existing Campaign, Chapter, SessionScreen, and SessionComponent I've already created to load exactly as before, so that the internal refactor is invisible to me.
16. As a developer, I want each subclass's persisted kind string to exactly match the value already stored in existing databases, so that no schema migration is required for this change.
17. As a developer editing a payload in place, I want to mutate its fields directly and pass the same SessionComponent to the save callback, so that the existing "mutate then save" pattern in the editor widgets doesn't need to change shape.
18. As a developer writing serialization for these classes, I want plain hand-written methods with no code generation step, so that the workflow matches how Character and Campaign are already modeled.
19. As a developer, I want this cutover to land as one commit with a green suite, so that the repository is never in a state where a payload is half map and half typed object.
20. As a developer, I want the kinds that are addable from the menu to be exactly the registry's contents, so that the "unsupported" placeholder kind can never be offered as something a DM can create.

## Implementation Decisions

- **Sealed hierarchy is the live representation.** `ComponentData` (already built, currently dead code) becomes the type of `SessionComponent`'s payload, replacing `Map<String, dynamic>`. Subclasses: narrative text, NPC stat block, initiative tracker, custom table, image, plus the unknown/unreadable case.
- **`SessionComponent` drops its kind field.** It carries id, screen id, order, and payload. Its kind is the payload's `dbKey`. The `ComponentType` enum and its label extension are deleted.
- **Persistence mapping.** Reading a row dispatches the persisted kind string plus the raw JSON through the model's `fromDb` entry point. Writing a row takes the kind string from the payload's `dbKey` and the JSON from the payload's serializer. An unknown payload writes back its original kind string, never a substitute.
- **Single registry, replacing the two-list design originally sketched.** The model layer exposes one ordered list of descriptors, each pairing a kind's persisted identity, its empty-instance factory, and its parser. This one list drives both parse dispatch and the addable-kinds menu. The identity is sourced from each subclass's own constant so it is written once. The unknown case is excluded from the registry — it is not addable. The list is compile-time constant (static tearoffs). Shape, as settled during design review:

  ```dart
  class _Kind {
    final String dbKey;
    final ComponentData Function() empty;
    final ComponentData Function(Map<String, dynamic>) fromJson;
    const _Kind(this.dbKey, this.empty, this.fromJson);
  }
  ```

- **Seed factory distinct from parse defaults.** Each subclass gains a hand-written empty-instance factory carrying the current defaults' seed values verbatim (a friendly NPC name, challenge rating, passive perception, and so on). It does **not** delegate to the parser, whose fallbacks for missing keys are deliberately neutral and serve a different purpose. The old defaults class is deleted once its bodies have moved.
- **Unknown covers two cases, not one.** Parse dispatch returns the unknown payload both for an unrecognized kind string and for a *recognized* kind whose JSON fails to decode — the decode is guarded, so a corrupt row degrades to a preserved-bytes placeholder instead of throwing during a SessionScreen load.
- **Icon and label become exhaustive switches over the sealed type, in the UI layer.** This keeps `IconData` out of the model (preserving the layering ADR-0001 intended) while buying compiler exhaustiveness that a kind-string-keyed map would not. The add menu iterates the registry and resolves each entry's icon and label by passing its empty instance through those switches.
- **Content dispatch becomes exhaustive switches over the payload.** Both the SessionScreen editing view and the live-play view switch on the payload's sealed type. Because the unknown case is now inhabitable, exhaustiveness forces both to handle it: a minimal read-only placeholder naming the persisted kind, offering no editor and never firing the save callback, so raw bytes survive. It does not attempt to interpret the raw JSON.
- **Editing widgets keep their current constructor shape.** Each keeps taking a `SessionComponent` and casts its payload to the concrete subclass internally, then reads and mutates typed fields and passes the same object to the save callback. The cast is safe because the dispatching switch has already matched the kind. Redesigning these constructors to take a typed payload directly belongs to the renderer-unification work, not here.
- **Guard ledger.** After cutover, adding a kind is a build error at four sites (icon, label, editing content, play content). Only two surfaces remain un-compiler-guarded — the parse dispatch and the registry list — because construction from a string cannot be exhaustiveness-checked and Flutter offers no runtime enumeration of sealed subtypes. Those two are covered by test, not by types. This is an accepted, documented residual.
- **Atomic cutover.** Changing the payload's static type breaks every reader simultaneously, so there is no staged path and no back-compat shim: one commit, whole suite green. A temporary map-accessor shim was considered and rejected as throwaway work.
- **No schema change.** The components table is untouched; only the Dart-side representation of its kind and payload columns changes. The persisted kind strings are frozen by ADR-0001 precisely so this holds.

## Testing Decisions

A good test here asserts externally observable behavior — what a caller of the persistence seam gets back — not the internal shape of a switch or the existence of a registry entry. The registry is not asserted directly; it is exercised by iterating it and checking that each kind survives a real round-trip.

- **Single seam for all new coverage: the provider seam.** `ProviderContainer` over the existing `InMemoryDatabase` fake, wired through `databaseProvider`. This is the highest existing seam and it is sufficient, because the fake rebuilds every read as `fromMap(toMap())` — so a provider-level read genuinely exercises payload serialization, kind-string dispatch, and reconstruction, not a shortcut around them. No new seam is introduced.
- **Prior art**: the existing component provider test (read/add/save/delete, `order_index` ordering, screen-id filtering), which itself mirrors the Campaign reference test established by the database-seam work.
- Cases to add at that seam:
  - For every registry entry: persist a component built from that entry's empty instance, re-read, and assert it comes back as the matching subclass — one assertion loop covering registry completeness and per-kind round-trip together.
  - Persist a component whose payload is the unknown case with an unrecognized kind string; assert it re-reads as the unknown case with its kind string and raw JSON intact.
  - Persist a component whose payload is the unknown case carrying a *recognized* kind string and deliberately malformed JSON; assert the re-read degrades to the unknown case rather than throwing, with bytes preserved. This is how the corrupt-payload path is reachable from this seam without any new hook.
  - Rewrite the existing save test, which currently asserts on the deleted kind field, to assert the re-read payload's subclass instead.
- **The existing model-layer test is left untouched.** It was delivered by the first issue in this feature, covers per-subclass field fidelity (which is genuinely awkward to assert from higher up), and its entry point's signature is unchanged by this cutover, so it keeps passing as-is. No new cases are added there.
- Manual verification supplements the automated seam: add, edit, and reload each of the five known kinds in a SessionScreen and confirm behavior is unchanged from before the refactor.

## Out of Scope

- **Unifying the editing and live-play renderers** into a single kind-dispatching render module, and the two duplicated inline component views that unification would collapse. That is a separate, larger change that builds on this one; the two content switches stay separate here, merely reading typed fields.
- Redesigning the editing widgets' constructors to receive a typed payload instead of a `SessionComponent` — that belongs with the renderer unification.
- Any schema change or upgrade path — the persisted kind strings are chosen specifically to avoid one.
- Code generation or a build step for serialization; immutable payloads with copy-with.
- Adding a sixth kind of SessionComponent.
- Widget-level tests that pump a widget to assert the "unsupported component" placeholder renders. That would require a new seam; the provider seam is the agreed single seam for this work.
- Any recovery or raw-JSON-inspection affordance for unreadable components beyond the labeled placeholder.
- Visual or UX redesign of the "add component" menu beyond wiring it to the registry.

## Further Notes

- Domain vocabulary above (`SessionComponent`, `ComponentData`, Campaign / Chapter / SessionScreen, Master Mode) matches `CONTEXT.md` at the repo root. Note that `CONTEXT.md` already describes the post-cutover shape — a SessionComponent holding a typed payload, "never a raw map" — so this work makes the code match a glossary that was written ahead of it.
- The first issue in this feature (the additive sealed hierarchy and its model tests) is complete. This PRD's remaining work is the cutover issue.
- This PRD implements ADR-0001. The single-registry and switch-based icon/label decisions recorded here amend that ADR's original two-lists-in-sync consequence; the amendment is already written into the ADR.
