# RPBoard

A Flutter companion app for tabletop RPG groups. A Dungeon Master builds campaigns and runs live sessions from prepared screens; players view and edit their own character sheets. Single-user, fully local (SQLite on device) — no accounts, no sync, no multiplayer.

## Features

- **Master Mode** — build Campaigns → Chapters → Scene (prepared session screens), each made of drag-reordered components: narrative text, NPC stat blocks, an initiative tracker, custom tables, images.
- **Edit Mode / Play Mode** — prepare a scene in Edit Mode, then run it at the table in Play Mode without leaving the screen.
- **PG Mode** — each player's own Character sheet: ability scores, proficiency bonus, skill and saving-throw bonuses, spell save DC and attack bonus, spell slots, death saves — all derived rules, computed on the `Character` model itself.
- Atomic, transactional reordering for every draggable list (Chapters, Scene, Components) — no partial/inconsistent order on failure.
- Typed, migration-safe persistence: a versioned schema ladder and typed component payloads instead of raw JSON maps.

## Tech stack

- [Flutter](https://flutter.dev) / Dart
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) for state management
- [go_router](https://pub.dev/packages/go_router) for navigation
- [sqflite](https://pub.dev/packages/sqflite) / [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) for on-device persistence

## Project docs

- [`CONTEXT.md`](CONTEXT.md) — domain vocabulary
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — codebase map
- [`docs/adr/`](docs/adr) — architecture decision records

## License

Copyright (c) 2026 Luca Zerbini. All rights reserved.

This repository is public for portfolio/showcase purposes. No license is granted to use, copy, modify, or distribute this code.
