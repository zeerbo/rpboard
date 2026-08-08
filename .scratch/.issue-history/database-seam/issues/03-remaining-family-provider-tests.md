# 03 — Provider tests for the remaining four families

**What to build:** Apply the Campaign reference pattern from ticket 02 to the other four list notifiers — `chapterListProvider`, `screenListProvider`, `componentListProvider`, `characterListProvider`. Each gets a `ProviderContainer` test overriding `databaseProvider` with a preloaded (or empty) `InMemoryDatabase`, asserting read/add/save/delete behavior through the seam plus each family's ordering and foreign-key filtering (chapters filtered by campaign and ordered `order_index ASC`, screens by chapter, components by screen, characters ordered `name ASC`). After this, all five families are covered and the seam has a full behavioral test suite.

**Blocked by:** 02 — reuses the `InMemoryDatabase` fake and the `ProviderContainer` override idiom it established.

**Status:** done

- [x] Chapter notifier: read/add/save/delete + `order_index ASC` + filtered by `campaign_id`
- [x] SessionScreen notifier: read/add/save/delete + `order_index ASC` + filtered by `chapter_id`
- [x] SessionComponent notifier: read/add/save/delete + `order_index ASC` + filtered by `screen_id`
- [x] Character notifier: read/add/save/delete + `name ASC`
- [x] All assert observable behavior only; pure-Dart, no widget pump, no real SQLite
- [x] Full suite green

---

**Done 2026-07-21.** Four new test files under `test/providers/`:
`chapter_provider_test.dart`, `screen_provider_test.dart`,
`component_provider_test.dart`, `character_provider_test.dart`. Each copies the
Campaign reference idiom (`ProviderContainer` + `databaseProvider` override over
`InMemoryDatabase`). Family notifiers keyed via `provider(param).future` /
`.notifier`. Family tests add a foreign-sibling exclusion case seeded directly
through the store. All five families now covered. `flutter analyze` clean; full
suite 39/39 green.
