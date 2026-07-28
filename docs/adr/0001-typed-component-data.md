---
status: accepted
---

# Typed ComponentData replaces untyped data Map

`SessionComponent.data` was a raw `Map<String, dynamic>` decoded from a JSON column, accessed by string key from widget code (`component.data['title']`) with no compile-time safety. We replaced it with a sealed `ComponentData` base class — one subclass per component kind (`NarrativeTextData`, `NpcStatBlockData`, `InitiativeTrackerData`, `CustomTableData`, `ImageData`), plus `UnknownComponentData` for unrecognized kinds — giving exhaustive, compiler-checked dispatch instead of stringly-typed map access.

## Considered Options

- **Codegen (`freezed`/`json_serializable`)** for the new classes — rejected, no reason to introduce `build_runner` for five simple classes when every existing model (`Character`, `Campaign`, ...) already hand-rolls `fromMap`/`toMap`.
- **Immutable classes + `copyWith`** — rejected in favor of mutable fields. The existing edit flow mutates in place then saves (single-user desktop app, no concurrency risk); immutability would only add hand-written `copyWith` boilerplate with no compensating safety benefit here.
- **Keep the `ComponentType` enum alongside the sealed classes** (dual representation, enum drives DB/menu, sealed class drives rendering) — rejected. It requires two switches (enum → empty instance, instance → enum) kept in sync on every new component kind. The sealed subclass is now the sole source of truth; each declares its own `dbKey`.
- **Silent fallback to `NarrativeTextData` for unrecognized `type` strings** (the old enum's behavior via `orElse`) — rejected as a data-loss-looking bug: an NPC stat block from a newer app version would silently render as a blank narrative box on an older build. Replaced with `UnknownComponentData(rawType, rawJson)`, rendered as a visible "unsupported component type" placeholder, preserving the original JSON so a later save doesn't destroy it.

## Consequences

- `dbKey` string constants are a frozen contract: they must exactly match the previous enum's `.name` values (`narrativeText`, `npcStatBlock`, `initiativeTracker`, `customTable`, `image`) since those strings are already persisted in the `components.type` column of every user's SQLite file. No DB migration was needed for this refactor *because* of that constraint — changing a `dbKey` later would require one.
- The "add component" menu registry is split across layers, but as a *single* model-side registry rather than the two-list design first sketched. The model layer exposes one `ComponentData.kinds` list of `{dbKey, empty, fromJson}` descriptors (no Flutter/UI imports) that drives both `fromDb` dispatch and the addable-kinds menu; `dbKey` is sourced from each subclass's `static const key` so it is written once. The UI layer keeps `IconData` out of the model by resolving icon/label with **exhaustive `switch`es over the sealed `ComponentData`** (`iconFor`/`labelFor`), *not* a `dbKey`→icon/label map — so adding a subclass is a compile error at those sites, which a map would not give. Net: of every per-kind surface, only `fromDb` and the `kinds` registry remain un-compiler-guarded (construction-from-a-string cannot be exhaustiveness-checked, and Flutter has no `dart:mirrors` to enumerate sealed subtypes); both are covered by a round-trip test. This amends the original two-lists-in-sync consequence.
- `UnknownComponentData` covers not only an unrecognized `dbKey` but also a *known* kind whose persisted JSON is malformed: `fromDb` catches a failing `jsonDecode` and preserves the raw bytes as `UnknownComponentData` rather than crashing the screen load, keeping the same no-silent-data-loss guarantee.
