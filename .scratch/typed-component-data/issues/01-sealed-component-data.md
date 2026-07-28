Status: done

# Model layer: sealed ComponentData + dbKey + round-trip tests

## Parent

[.scratch/typed-component-data/PRD.md](../PRD.md) — implements [ADR-0001](../../../docs/adr/0001-typed-component-data.md)

## What to build

Add a sealed `ComponentData` base class to the model layer with one subclass per component kind — `NarrativeTextData`, `NpcStatBlockData`, `InitiativeTrackerData`, `CustomTableData`, `ImageData` — plus `UnknownComponentData` for unrecognized kinds. Each subclass gets manual (no codegen) `fromJson`/`toJson` matching the field shapes currently produced by `ComponentDefaults` and consumed ad hoc via map keys.

Each subclass declares a `static const String dbKey` that exactly equals the current `ComponentType` enum's `.name` value for that kind (`narrativeText`, `npcStatBlock`, `initiativeTracker`, `customTable`, `image`) — these strings are already persisted in existing databases and must not change.

This is purely additive: the existing `ComponentType` enum, `SessionComponent.data` (`Map<String, dynamic>`), and all current widget code are left untouched and continue to work exactly as today. Nothing in the app references the new classes yet — that wiring is the next issue.

`UnknownComponentData` holds the raw persisted `type` string and the raw JSON string, so it can round-trip back out unchanged (no data loss for a kind this build doesn't recognize).

## Acceptance criteria

- [x] `ComponentData` sealed class exists with the 5 named subclasses + `UnknownComponentData`, each with `fromJson`/`toJson`
- [x] Each subclass's `dbKey` constant matches its corresponding legacy `ComponentType.name` string exactly
- [x] Round-trip test (construct → `toJson` → `fromJson` → equal fields) passes for each of the 5 known subclasses
- [x] A dispatch helper (e.g. `ComponentData.fromDb(String dbKey, String json)`) returns the correct subclass for each legacy `dbKey`, and returns `UnknownComponentData` (preserving the original key + raw JSON) for an unrecognized key
- [x] `UnknownComponentData.toJson`/re-serialization round-trips the original raw JSON unchanged
- [x] Existing `ComponentType` enum, `SessionComponent`, `ComponentDefaults`, and all widget files are unmodified — app still builds and behaves exactly as before
- [x] No new dependency on `freezed`/`json_serializable`/`build_runner`

## Blocked by

None - can start immediately.
