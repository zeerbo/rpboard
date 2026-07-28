import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character.dart';
import '../core/database/db.dart';

class CharacterListNotifier extends AsyncNotifier<List<Character>> {
  @override
  Future<List<Character>> build() => ref.read(databaseProvider).getCharacters();

  Future<void> add(Character c) async {
    await ref.read(databaseProvider).insertCharacter(c);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(databaseProvider).deleteCharacter(id);
    ref.invalidateSelf();
  }
}

final characterListProvider =
    AsyncNotifierProvider<CharacterListNotifier, List<Character>>(
  CharacterListNotifier.new,
);

/// Single-item Character provider, keyed by id. The one writer for updates to
/// an existing Character — [save] owns invalidating both itself and
/// [characterListProvider]. This is the fix for the PRD's headline bug:
/// CharacterSheetScreen's debounce-save used to bypass the provider graph
/// entirely. See ADR-0004.
class CharacterNotifier extends FamilyAsyncNotifier<Character?, String> {
  @override
  Future<Character?> build(String id) =>
      ref.read(databaseProvider).getCharacter(id);

  Future<void> save(Character c) async {
    await ref.read(databaseProvider).updateCharacter(c);
    ref.invalidateSelf();
    ref.invalidate(characterListProvider);
  }
}

final characterProvider =
    AsyncNotifierProvider.family<CharacterNotifier, Character?, String>(
  CharacterNotifier.new,
);
