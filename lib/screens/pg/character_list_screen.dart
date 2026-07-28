import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../models/character.dart';
import '../../providers/character_provider.dart';

const _uuid = Uuid();

class CharacterListScreen extends ConsumerWidget {
  const CharacterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chars = ref.watch(characterListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personaggi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCharacter(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Personaggio'),
      ),
      body: chars.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (list) => list.isEmpty
            ? _EmptyState(onTap: () => _createCharacter(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _CharacterTile(
                  character: list[i],
                  onTap: () => context.go('/characters/${list[i].id}'),
                  onDelete: () => _deleteCharacter(context, ref, list[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _createCharacter(BuildContext context, WidgetRef ref) async {
    final name = await _showNameDialog(context);
    if (name == null || name.trim().isEmpty) return;

    final c = Character(id: _uuid.v4(), name: name.trim());
    await ref.read(characterListProvider.notifier).add(c);
    if (context.mounted) context.go('/characters/${c.id}');
  }

  Future<void> _deleteCharacter(
      BuildContext context, WidgetRef ref, Character c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina Personaggio'),
        content: Text('Eliminare "${c.name}"?\nQuesta azione non è reversibile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(characterListProvider.notifier).delete(c.id);
    }
  }
}

Future<String?> _showNameDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Nuovo Personaggio'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(hintText: 'Nome del personaggio'),
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Crea'),
        ),
      ],
    ),
  );
}

class _CharacterTile extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CharacterTile({
    required this.character,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (character.race.isNotEmpty) character.race,
      if (character.characterClass.isNotEmpty) character.characterClass,
      'Liv. ${character.level}',
    ].join(' • ');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.accent.withOpacity(0.15),
          child: Text(
            character.name.isNotEmpty
                ? character.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          character.name.isEmpty ? '(senza nome)' : character.name,
          style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PF ${character.hpCurrent}/${character.hpMax}',
                style: TextStyle(
                  color: _hpColor(character),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.onSurfaceMuted, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Color _hpColor(Character c) {
    if (c.hpMax == 0) return AppTheme.onSurfaceMuted;
    final ratio = c.hpCurrent / c.hpMax;
    if (ratio <= 0) return AppTheme.danger;
    if (ratio <= 0.5) return AppTheme.warning;
    return AppTheme.success;
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_add_outlined,
              size: 72, color: AppTheme.onSurfaceMuted),
          const SizedBox(height: 16),
          const Text(
            'Nessun personaggio',
            style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea il tuo primo personaggio',
            style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: const Text('Crea Personaggio'),
          ),
        ],
      ),
    );
  }
}
