Status: ready-for-agent

# A seam in front of the persistence layer

Implements architecture-review candidate **C2** (`docs/architecture-review.html#c2`). A new ADR-0002 should record the accepted decision this PRD implements; it relates to [ADR-0001](../../docs/adr/0001-typed-component-data.md), whose frozen `dbKey`s assume a migration path that only becomes reachable once this seam exists.

## Problem Statement

Every read and write of a Campaign, Chapter, SessionScreen, SessionComponent, or Character funnels through `AppDatabase.instance` — a single static singleton. The providers reach it, and five screens across Master Mode and PG Mode reach it directly as well (single-item loads in `initState`, reorder write-loops, the Character autosave). Because the singleton is a hard global, there is no point at which the real SQLite database can be swapped for a fake. Consequently nothing above the database is testable: the entire suite is one file (`test/models/component_test.dart`), and it only exercises pure model code that never touches persistence.

Three of the other review candidates (C3 reorder atomicity, C4 single-item providers, C6 schema migrations) are all blocked on this: each needs to assert behavior against a database it can control, and today no such control point exists.

## Solution

Introduce a `Database` interface — the seam — that declares exactly the CRUD surface the app already uses. The real SQLite implementation becomes one adapter behind it (`SqfliteDatabase`); a behavioral in-memory fake becomes a second adapter used only in tests (`InMemoryDatabase`). The seam is published as a Riverpod `databaseProvider`, and every caller — providers and screens alike — obtains the database through that provider instead of the static singleton. The static `AppDatabase.instance` is deleted.

The change is strictly behavior-preserving. No schema change, no data migration, no user-visible difference. What it buys is a single override point: a test wraps its subject in a `ProviderScope`/`ProviderContainer` that overrides `databaseProvider` with an `InMemoryDatabase`, and for the first time the providers (and later the screens) can be tested without a real device database.

## User Stories

1. As a developer, I want a `Database` interface that names the CRUD operations the app performs, so that persistence has one documented shape instead of an implicit static surface.
2. As a developer, I want the real SQLite code to live behind that interface as `SqfliteDatabase`, so that the sqflite/ffi/path details are hidden from every caller.
3. As a developer writing a provider test, I want to override `databaseProvider` with an in-memory fake, so that I can assert the notifier's behavior without opening a real database file.
4. As a developer, I want `InMemoryDatabase` to honor the same ordering and foreign-key filtering as the real adapter (e.g. Chapters returned by `order_index ASC`, Chapters filtered by their Campaign), so that a test that passes against the fake reflects how production actually reads.
5. As a developer, I want the static `AppDatabase.instance` singleton removed entirely, so that no code path can silently reach around the seam.
6. As a developer maintaining the Campaign/Chapter/SessionScreen/SessionComponent/Character list providers, I want each to read the database via `ref.read(databaseProvider)`, so that the provider under test uses whichever adapter the test injected.
7. As a developer working on any of the five screens that load a single entity directly, I want those calls routed through `ref.read(databaseProvider)` too, so that after this change nothing anywhere depends on a static global.
8. As a developer, I want the interface to expose CRUD only — no `init`/`open`/`close` — so that callers never reason about connection lifecycle and the lazy-open stays hidden in the SQLite adapter.
9. As a developer, I want the `InMemoryDatabase` fake to live under `test/`, so that the shipped app bundle contains no test double and no production code can depend on it.
10. As a developer, I want at least one `ProviderContainer` test proving the seam mechanics end-to-end (override binds → notifier reads the fake → `invalidateSelf` re-reads), so that the seam is demonstrably working and there is a pattern to copy for the other families.
11. As a DM using Master Mode, I want every Campaign, Chapter, SessionScreen, and SessionComponent to load and save exactly as before, so that this internal refactor is invisible to me.
12. As a player in PG Mode, I want my Character sheet to load, autosave, and persist exactly as before, so that the refactor doesn't disturb the debounced save behavior.
13. As a developer picking up C4 (single-item providers), I want the screens already reading through `databaseProvider`, so that swapping their direct reads for `ref.watch(entityProvider)` is a localized change with the seam already in place.
14. As a developer picking up C3 (reorder) or C6 (migrations), I want the seam to exist so that those modules can be built and tested behind it, without each having to invent its own persistence abstraction.

## Implementation Decisions

- **One `Database` interface, not per-aggregate repositories.** A single `abstract class Database` declares all five CRUD families (Character, Campaign, Chapter, SessionScreen, SessionComponent) — the same ~25 async methods `AppDatabase` exposes today. This is a mechanical extraction; splitting into per-aggregate repositories is a separate, later move and is explicitly not done here.
- **Naming.** The seam is `Database`; the two adapters are `SqfliteDatabase` and `InMemoryDatabase`. `Database` is registered in CONTEXT.md as the persistence seam. (The sqflite package's own `Database` type stays confined inside the SQLite adapter, so the name collision lives in exactly one file.)
- **Injection via Riverpod `ref.read`.** The seam is published as `databaseProvider` (a plain `Provider<Database>` whose default builds `SqfliteDatabase()`). Every list notifier obtains the database with `ref.read(databaseProvider)` — `read`, not `watch`, because the database instance is stable and must not trigger rebuilds.
- **Screens go through the seam, but not yet through single-item providers.** The five screens that call the singleton directly for single-entity loads and reorder write-loops switch to `ref.read(databaseProvider)` (all five are already `ConsumerState`, so `ref` is in scope). Replacing those direct reads with dedicated single-item providers is C4's job and is out of scope here — this PRD only removes the static global.
- **Pure-CRUD interface — no lifecycle.** The interface declares CRUD only. The lazy-open (`_db ??= _open()`), the ffi initialization, and the application-documents path resolution all stay private inside `SqfliteDatabase`. `InMemoryDatabase` needs no open step; a fresh instance is ready immediately, and test teardown is handled by GC.
- **`InMemoryDatabase` is a behavioral fake.** Backed by per-table maps keyed by id, it reproduces the real adapter's ordering (`name ASC`, `updated_at DESC`, `order_index ASC`) and foreign-key filtering (e.g. Chapters by `campaign_id`, SessionScreens by `chapter_id`, SessionComponents by `screen_id`). It is **not** a canned-response stub.
- **Cascade delete is not simulated.** The real adapter relies on SQLite `ON DELETE CASCADE`. A map-backed fake cannot faithfully reproduce it without reimplementing SQLite, so `InMemoryDatabase` does not attempt cascade semantics. Deletion-cascade behavior is therefore not asserted at the fake seam (see Testing Decisions and Out of Scope).
- **CRUD parity — no transaction primitive added.** The interface mirrors today's methods exactly; the reorder write-loops remain N separate update calls, now issued through the seam. Introducing a transaction/batch operation for atomic reorder is C3's decision and is not pre-installed here.
- **File layout.** The single `db.dart` splits into: the interface, the renamed SQLite adapter (`AppDatabase` → `SqfliteDatabase implements Database`, static `instance` removed), and the `databaseProvider`. The `InMemoryDatabase` fake lives under `test/support/`.
- **No schema change, no migration.** The `characters`/`campaigns`/`chapters`/`session_screens`/`components` tables and their DDL are untouched. `onUpgrade` remains absent — adding it is C6.
- **ADR-0002.** A new ADR records the accepted decision: the `Database` seam, Riverpod `ref.read` injection, and the two-adapter arrangement with `InMemoryDatabase` as the test surface, noting its relationship to ADR-0001's frozen `dbKey`s.

## Testing Decisions

- **What a good test asserts here:** external behavior observed through the seam — that a notifier, given a database preloaded (or empty), reads back the correct entities in the correct order, and that a mutation followed by `invalidateSelf` reflects the new state. Tests must not assert on private fields, call counts, or the fact that `ref.read(databaseProvider)` was invoked; those are implementation details.
- **The single test seam is `databaseProvider`.** Tests construct a `ProviderContainer` (or `ProviderScope`) overriding `databaseProvider` with an `InMemoryDatabase`. This is the highest available seam — it sits above both the providers and the screens — so a single override point covers every caller.
- **Modules tested:** the five list notifiers (`campaignListProvider`, `chapterListProvider`, `screenListProvider`, `componentListProvider`, `characterListProvider`). At minimum, the Campaign family is fully covered as the reference pattern: read empty → `add` → read again asserts the list grew and is correctly sorted; `save`/`delete` reflected on re-read. The same pattern is then applied to the remaining families.
- **These are pure-Dart tests, no widget pump and no real SQLite** — matching the "testabile senza Flutter" intent. The `InMemoryDatabase` fake itself is exercised transitively by these tests (its ordering/filtering must be correct for the assertions to hold).
- **Prior art:** `test/models/component_test.dart` is the only existing test — a pure-Dart, no-Flutter model round-trip test. This PRD establishes the first *provider-level* test, using the same pure-Dart, no-widget discipline, with the `ProviderContainer` override as the new setup idiom.

## Out of Scope

- Single-item entity providers (`campaignProvider`, `chapterProvider`, `screenProvider`, `characterProvider`) and routing screen reads through them — that is **C4**, which depends on this seam.
- Atomic reorder / a transaction primitive on the interface — that is **C3**.
- Schema migrations / `onUpgrade` / a `Migrations` module — that is **C6**.
- Splitting `Database` into per-aggregate repositories.
- Cascade-delete behavior in `InMemoryDatabase`, and any test asserting cascade at the fake seam. If cascade needs coverage it belongs to a real-adapter/integration test, not the in-memory fake.
- Widget/pumped-screen tests — those become worthwhile after C4 introduces single-item providers.
- Any change to the `SessionComponent` `data` payload (the untyped `Map` vs typed `ComponentData`) — that is C1/ADR-0001, orthogonal to this seam.

## Further Notes

- This is the review's recommended starting point ("da dove partirei: C2"): C3, C4, C6, and C7 all become testable only after it, and it is the cheapest of the set because the interface already exists implicitly inside `AppDatabase` and only needs to be extracted and injected.
- Blast radius is small and mechanical: two provider files switch to `ref.read(databaseProvider)`, five screens swap `AppDatabase.instance` for `ref.read(databaseProvider)`, and one database file splits into interface + adapter + provider. No behavior changes.
- Sharpest risk to watch during implementation: the `InMemoryDatabase` fake diverging from `SqfliteDatabase` on ordering/filtering. Keep the fake's query semantics deliberately aligned with the real adapter's `orderBy`/`where` clauses, and treat cascade as knowingly out of the fake's remit rather than a bug.
