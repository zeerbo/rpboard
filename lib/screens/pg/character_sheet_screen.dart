import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/character.dart';
import '../../providers/character_provider.dart';
import 'character_sheet/info_tab.dart';
import 'character_sheet/statistiche_tab.dart';
import 'character_sheet/combattimento_tab.dart';
import 'character_sheet/equipaggiamento_tab.dart';
import 'character_sheet/magie_tab.dart';
import 'character_sheet/bio_tab.dart';
import 'character_sheet/note_tab.dart';

/// The Character sheet screen, shrunk (C7) to exactly what the PRD calls
/// for: the [TabController], the current [Character], the debounce [Timer],
/// and the save call. Every field lives in one of the seven tab widgets
/// under `character_sheet/`, each owning its own controllers and writing
/// straight into [_char] on change — this screen never touches a
/// per-field value or syncs a controller map.
class CharacterSheetScreen extends ConsumerStatefulWidget {
  final String characterId;
  const CharacterSheetScreen({super.key, required this.characterId});

  @override
  ConsumerState<CharacterSheetScreen> createState() => _CharacterSheetState();
}

class _CharacterSheetState extends ConsumerState<CharacterSheetScreen>
    with TickerProviderStateMixin {
  late TabController _tabs;
  Character? _char;
  CharacterNotifier? _notifier;
  bool _redirecting = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    _tabs.dispose();
    super.dispose();
  }

  /// Seeds `_char` from the provider's first successful load. Guarded so a
  /// rebuild triggered by our own save (which invalidates the provider)
  /// never clobbers in-progress local edits — the working copy in `_char`
  /// stays the source of truth between saves.
  void _seedFromLoaded(Character char) {
    if (_char != null) return;
    _char = char;
    // Cached once, up front, so `_saveNow()` never has to call `ref.read`
    // from `dispose()`: by the time `State.dispose()` runs, the element's
    // `context.mounted` (Riverpod's own liveness flag, distinct from
    // Flutter's `State.mounted`) is already false, and `ref.read` throws.
    // The notifier itself is owned by the ProviderContainer, not by this
    // Element, so holding onto it across the widget's lifecycle is safe.
    _notifier = ref.read(characterProvider(widget.characterId).notifier);
  }

  /// A missing Character (e.g. cascade-deleted elsewhere) redirects back to
  /// the character list. Deferred to a post-frame callback since navigating
  /// away during `build` is unsafe.
  void _redirectToList() {
    if (_redirecting) return;
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/characters');
    });
  }

  void _schedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    if (_char == null || _notifier == null) return;
    _notifier!.save(_char!);
  }

  /// Passed to every tab as the "notify the parent to schedule a save"
  /// callback. Each tab has already written its edit straight into `_char`
  /// by the time this runs; `setState` here just re-renders anything
  /// outside the edited tab that also depends on `_char` (e.g. the AppBar
  /// title), matching the pre-split screen's live-update behavior.
  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
    _schedSave();
  }

  @override
  Widget build(BuildContext context) {
    if (_char == null) {
      // Not yet seeded from the provider: render loading/error/missing.
      // Once seeded (below), `_char` — the local working copy — drives the
      // UI directly and is no longer replaced by subsequent provider
      // rebuilds (e.g. the ones our own save() triggers).
      final asyncChar = ref.watch(characterProvider(widget.characterId));
      return asyncChar.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Errore: $e'))),
        data: (char) {
          if (char == null) {
            _redirectToList();
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          _seedFromLoaded(char);
          return _buildSheet(_char!);
        },
      );
    }

    return _buildSheet(_char!);
  }

  Widget _buildSheet(Character c) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _saveNow();
            context.go('/characters');
          },
        ),
        title: Text(c.name.isEmpty ? 'Personaggio' : c.name),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Statistiche'),
            Tab(text: 'Combattimento'),
            Tab(text: 'Equipaggiamento'),
            Tab(text: 'Magie'),
            Tab(text: 'Bio'),
            Tab(text: 'Note'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          InfoTab(character: c, onChanged: _onFieldChanged),
          StatisticheTab(character: c, onChanged: _onFieldChanged),
          CombattimentoTab(character: c, onChanged: _onFieldChanged),
          EquipaggiamentoTab(character: c, onChanged: _onFieldChanged),
          MagieTab(character: c, onChanged: _onFieldChanged),
          BioTab(character: c, onChanged: _onFieldChanged),
          NoteTab(character: c, onChanged: _onFieldChanged),
        ],
      ),
    );
  }
}
