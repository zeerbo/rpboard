Status: done

# Cutover: wire SessionComponent to typed data, migrate all consumers, remove ComponentType

## Parent

[.scratch/typed-component-data/PRD.md](../PRD.md) — implements [ADR-0001](../../../docs/adr/0001-typed-component-data.md) (see the amended Consequence #2)

## What to build

Switch `SessionComponent.data`'s type from `Map<String, dynamic>` to the sealed `ComponentData` (built in issue 01), and delete the `ComponentType` enum entirely — the sealed subclass is now the sole representation of "what kind of component is this." `SessionComponent` drops its `type` field; kind is read from `data.dbKey`. `fromMap`/`toMap` use `ComponentData.fromDb` and `data.dbKey` instead of the enum.

This is one **atomic** change: the `Map → ComponentData` field swap breaks every reader at once, so there is no partial/staged state and no back-compat shim. One commit, whole suite green.

### Model layer (`lib/models/component.dart`)

- Each concrete subclass gains a **`static empty()`** factory holding the current `ComponentDefaults.<kind>()` seed values **verbatim** (e.g. NPC seeds `'Nuovo NPC'`, `cr '1'`, `xp 200`, `senses 'Percezione passiva 10'`). `empty()` is hand-written and **independent of `fromJson`** — `fromJson`'s neutral fallbacks (`''`, `ac 10`, `xp 0`) are a different intent (tolerant parse) and must not be reused for `empty()`. Delete `ComponentDefaults` once its bodies have moved.
- **Single registry** replacing both the `fromDb` switch and any "list of addable kinds":

  ```dart
  class _Kind {
    final String dbKey;
    final ComponentData Function() empty;
    final ComponentData Function(Map<String, dynamic>) fromJson;
    const _Kind(this.dbKey, this.empty, this.fromJson);
  }

  static const kinds = [
    _Kind(NarrativeTextData.key,     NarrativeTextData.empty,     NarrativeTextData.fromJson),
    _Kind(NpcStatBlockData.key,      NpcStatBlockData.empty,      NpcStatBlockData.fromJson),
    _Kind(InitiativeTrackerData.key, InitiativeTrackerData.empty, InitiativeTrackerData.fromJson),
    _Kind(CustomTableData.key,       CustomTableData.empty,       CustomTableData.fromJson),
    _Kind(ImageData.key,             ImageData.empty,             ImageData.fromJson),
  ];
  ```

  `dbKey` is sourced from each subclass's `static const key` (one literal, no drift). `UnknownComponentData` is **excluded** — you cannot "add" one. `const` via static tearoffs.
- `ComponentData.fromDb(dbKey, json)`: look up `kinds.firstWhere((k) => k.dbKey == dbKey).fromJson(map)`; on no match → `UnknownComponentData(rawType: dbKey, rawJson: json)`. **Wrap the `jsonDecode` in `try`**: malformed JSON for a *known* dbKey (e.g. a truncated write) must also degrade to `UnknownComponentData(rawType: dbKey, rawJson: json)`, not crash the screen load. `UnknownComponentData` thus means "cannot safely interpret — preserve the bytes," covering both unknown kind and corrupt payload.
- `SessionComponent.fromMap`: `data: ComponentData.fromDb(row['type'], row['data'] ?? '{}')`. `toMap`: `'type': data.dbKey`, `'data': data.toJson()`.

### UI layer (`session_edit_screen.dart`, `session_play_screen.dart`)

- Replace `_componentIcon(ComponentType)` and `ComponentTypeLabel.label` with `iconFor(ComponentData)` and `labelFor(ComponentData)` implemented as **exhaustive `switch` over the sealed `ComponentData`** (IconData stays in the UI layer — ADR-0001 layering — but the switch buys compiler exhaustiveness a `dbKey`→icon/label *map* would not). Unknown → warning icon + `rawType` label. The add-component menu iterates `ComponentData.kinds`, calling `iconFor(k.empty())` / `labelFor(k.empty())`.
- The edit-content and play-content dispatch become exhaustive `switch (component.data)` over the sealed type. Because `UnknownComponentData` is now a possible `component.data`, exhaustiveness **forces** an Unknown case in both: a minimal, read-only "componente non supportato: {rawType}" placeholder (no editor, `onUpdate` never fires → `rawJson` preserved). Do not interpret `rawJson`.
- The five editing widgets keep their `SessionComponent component` constructor param and **cast internally** (`final d = component.data as NarrativeTextData;`), reading/writing typed fields and passing the same `component` to `onUpdate`. The cast is safe (the switch already matched the kind); the typed render seam / constructor redesign is deferred to C5, not this issue.

### Scope boundary

Data-model cutover only. Unifying edit/play into one typed renderer (`render(data, isEditMode)`) is **C5** and out of scope here — the two render switches stay separate, just reading typed fields.

No SQLite schema change — `components` table (`type`/`data` columns) untouched; only the Dart-side representation changes.

## Guard ledger (why this shape)

After cutover, adding a 6th kind: the four sealed switches (`iconFor`, `labelFor`, edit-content, play-content) go non-exhaustive → **compile error** (the enum never gave this). Only two surfaces stay un-compiler-guarded — `fromDb` and the `kinds` registry — because construction-from-a-string cannot be exhaustiveness-checked (no `dart:mirrors` on Flutter). Those two are covered by the round-trip test below.

## Acceptance criteria

- [x] `ComponentType` enum, `ComponentTypeLabel`, `ComponentDefaults`, `_componentIcon`, and `SessionComponent.type` are deleted; no remaining references
- [x] `SessionComponent.data` is typed `ComponentData`; `fromMap`/`toMap` dispatch via `dbKey`, not the old enum
- [x] A single `ComponentData.kinds` registry (dbKey + `empty` + `fromJson`) drives both `fromDb` and the add-component menu; `UnknownComponentData` is excluded from it; `dbKey` comes from each subclass's `static const key`
- [x] Each subclass has a hand-written `empty()` carrying the old `ComponentDefaults` seed values, independent of `fromJson`
- [x] `iconFor`/`labelFor` are exhaustive switches over `ComponentData`; the edit-content and play-content dispatches are exhaustive switches over `ComponentData` — adding a subclass produces compile errors at all four sites until handled
- [x] All five editing widgets (narrative, NPC, initiative, custom table, image) use typed field access via an internal cast; `onUpdate(component)` still fires with the same `SessionComponent`
- [x] Opening a screen with an unrecognized persisted `type` renders a visible read-only "componente non supportato: {rawType}" placeholder in both edit and play modes; re-saving does not alter the original raw data
- [x] A component whose known-kind `data` JSON is malformed loads as `UnknownComponentData` (placeholder shown), not a crash, and its raw bytes survive a re-save
- [x] All new coverage lands at the **provider seam** (`test/providers/component_provider_test.dart`) — no new test seam is introduced. `InMemoryDatabase` rebuilds reads as `fromMap(toMap())`, so a provider-level read genuinely exercises `toJson`/`fromDb`
- [x] **Registry round-trip test** at that seam: for each entry in `ComponentData.kinds`, persist a component built from `k.empty()`, re-read, assert it returns as the matching subclass
- [x] Unknown-kind test at that seam: persist `UnknownComponentData(rawType: <unrecognized>, rawJson: ...)`, assert re-read preserves both `rawType` and `rawJson`
- [x] Malformed-payload test at that seam: persist `UnknownComponentData(rawType: 'narrativeText', rawJson: '<invalid json>')` — `toMap` writes a *known* kind with corrupt JSON — and assert the re-read degrades to `UnknownComponentData` without throwing, bytes preserved
- [x] Existing provider test rewritten in the same commit: helper takes a `ComponentData` (not `ComponentType`); the former `list.single.type == ComponentType.initiativeTracker` assertion becomes `list.single.data is InitiativeTrackerData`
- [x] `test/models/component_test.dart` left **untouched** — it covers per-subclass field fidelity from issue 01 and `fromDb`'s signature is unchanged, so it must keep passing as-is
- [x] Manually verified end-to-end: add, edit, and reload each of the 5 known kinds; behavior unchanged from before the refactor
- [x] `flutter analyze` clean; full `flutter test` green

## Blocked by

- [.scratch/typed-component-data/issues/01-sealed-component-data.md](01-sealed-component-data.md) — done
