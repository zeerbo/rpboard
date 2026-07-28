# 02 — InMemoryDatabase fake + Campaign-family reference test

**What to build:** A behavioral `InMemoryDatabase implements Database` fake living under `test/support/` (never `lib/`, so the shipped bundle carries no test double). Backed by per-table maps keyed by id, it reproduces the real adapter's ordering (`name ASC` for characters, `updated_at DESC` for campaigns, `order_index ASC` for chapters/screens/components) and foreign-key filtering (chapters by `campaign_id`, screens by `chapter_id`, components by `screen_id`) for all five families — it is a behavioral fake, not a canned-response stub. Cascade delete is deliberately NOT simulated. Then the first provider-level test in the repo: a `ProviderContainer` overriding `databaseProvider` with an `InMemoryDatabase`, asserting the Campaign notifier's external behavior end-to-end — read empty → `add` → re-read shows the list grew and is correctly sorted; `save`/`delete` reflected on re-read; a mutation followed by `invalidateSelf` re-reads the fake (proves the seam binds). Pure-Dart, no widget pump, no real SQLite. This is the copy-me pattern for the remaining families.

**Blocked by:** 01 — the seam and `databaseProvider` must exist.

**Status:** done

- [x] `InMemoryDatabase implements Database` under `test/support/`; nothing in `lib/` depends on it
- [x] Ordering parity for all five families: `name ASC`, `updated_at DESC`, `order_index ASC`
- [x] FK filtering: chapters by `campaign_id`, screens by `chapter_id`, components by `screen_id`
- [x] Cascade delete NOT simulated; no test asserts cascade at the fake seam
- [x] Campaign-family `ProviderContainer` test: read-empty → add → re-read grown + sorted; save/delete reflected
- [x] `invalidateSelf` re-read asserted (seam-mechanics proof)
- [x] Tests assert observable behavior only — no private fields, no call counts, no "ref.read was invoked"
- [x] Pure-Dart, no widget pump, no real SQLite; `flutter test` green

---

**Implementation notes (2026-07-21):**
- Fake: `test/support/in_memory_database.dart` — per-table maps keyed by id, sort/filter mirror `SqfliteDatabase`. `insert*` upserts (mirrors `ConflictAlgorithm.replace`), `update*` no-ops on missing id, cascade deliberately omitted (documented in class doc).
- Test: `test/providers/campaign_provider_test.dart` — 6 tests: read-empty, add-grows, sorted `updated_at DESC`, save reflected, delete reflected, external-write + `invalidate` re-read (seam-binding proof). Copy-me pattern for other families.
- Full suite green: 12 tests. `flutter analyze` clean.
