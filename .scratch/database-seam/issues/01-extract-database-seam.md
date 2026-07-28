# 01 — Extract the Database seam, wire it, delete the static global

**What to build:** The single `db.dart` splits into three things — a `Database` interface declaring the ~22 async CRUD methods the app already performs (Character, Campaign, Chapter, SessionScreen, SessionComponent families), a `SqfliteDatabase implements Database` adapter holding all the real sqflite/ffi/path/lazy-open detail privately, and a `databaseProvider` (`Provider<Database>` whose default builds `SqfliteDatabase()`). Both provider files (`campaign_provider`, `character_provider`) and all five screens that reach the singleton directly (`campaign_screen`, `chapter_screen`, `session_edit_screen`, `session_play_screen`, `character_sheet_screen`) obtain the database via `ref.read(databaseProvider)` instead of `AppDatabase.instance`. The `AppDatabase` class and its static `instance` are deleted. After this ticket, Master Mode (Campaign/Chapter/Screen/Component load, save, reorder write-loops) and PG Mode (Character load + debounced autosave) behave exactly as before — pure behavior-preserving refactor.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] `Database` interface declares CRUD only — no `init`/`open`/`close`; lifecycle stays private in the adapter
- [x] `SqfliteDatabase implements Database`; lazy-open, ffi init, application-documents path resolution all private; sqflite's own `Database` type confined to this one file
- [x] `databaseProvider` published; default builds `SqfliteDatabase()`
- [x] All 7 call sites use `ref.read(databaseProvider)` (`read`, not `watch`) — 2 provider files + 5 screens
- [x] `AppDatabase` name and static `instance` deleted; `grep AppDatabase lib/` returns nothing
- [x] No schema change, no migration, `onUpgrade` still absent
- [x] `flutter analyze` clean; app runs identically in Master Mode and PG Mode
