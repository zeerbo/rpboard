import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/character.dart';
import 'shared_widgets.dart';

/// Info tab: identity fields (name, race, class, level, background,
/// alignment, player name, experience) plus the inspiration checkbox and the
/// read-only proficiency-bonus / passive-perception chips.
///
/// Owns controllers only for its own fields. Every edit writes straight into
/// [character] and calls [onChanged] to notify the parent to schedule a save
/// — there is no sync-on-save step.
class InfoTab extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const InfoTab({super.key, required this.character, required this.onChanged});

  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab> {
  late final TextEditingController _name;
  late final TextEditingController _race;
  late final TextEditingController _level;
  late final TextEditingController _class;
  late final TextEditingController _subclass;
  late final TextEditingController _background;
  late final TextEditingController _alignment;
  late final TextEditingController _playerName;
  late final TextEditingController _xp;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _name = TextEditingController(text: c.name);
    _race = TextEditingController(text: c.race);
    _level = TextEditingController(text: c.level.toString());
    _class = TextEditingController(text: c.characterClass);
    _subclass = TextEditingController(text: c.subclass);
    _background = TextEditingController(text: c.background);
    _alignment = TextEditingController(text: c.alignment);
    _playerName = TextEditingController(text: c.playerName);
    _xp = TextEditingController(text: c.experiencePoints.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _race.dispose();
    _level.dispose();
    _class.dispose();
    _subclass.dispose();
    _background.dispose();
    _alignment.dispose();
    _playerName.dispose();
    _xp.dispose();
    super.dispose();
  }

  void _edit(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTextField(
            controller: _name,
            label: 'Nome Personaggio',
            onEdited: (v) => _edit(() => c.name = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _race,
                label: 'Razza',
                onEdited: (v) => _edit(() => c.race = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: SheetTextField(
                controller: _level,
                label: 'Livello',
                numeric: true,
                onEdited: (v) => _edit(() => c.level = int.tryParse(v) ?? 1),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _class,
                label: 'Classe',
                onEdited: (v) => _edit(() => c.characterClass = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _subclass,
                label: 'Sottoclasse',
                onEdited: (v) => _edit(() => c.subclass = v),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _background,
                label: 'Background',
                onEdited: (v) => _edit(() => c.background = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _alignment,
                label: 'Allineamento',
                onEdited: (v) => _edit(() => c.alignment = v),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _playerName,
                label: 'Nome Giocatore',
                onEdited: (v) => _edit(() => c.playerName = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: SheetTextField(
                controller: _xp,
                label: 'Esperienza',
                numeric: true,
                onEdited: (v) => _edit(() => c.experiencePoints = int.tryParse(v) ?? 0),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Generali'),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(
              value: c.hasInspiration,
              onChanged: (v) => _edit(() => c.hasInspiration = v ?? false),
            ),
            const Text('Ispirazione', style: TextStyle(color: AppTheme.onSurface)),
            const Spacer(),
            InfoChip('Bonus Competenza', '+${c.proficiencyBonus}'),
            const SizedBox(width: 8),
            InfoChip('Percezione Passiva', c.passivePerception),
          ]),
        ],
      ),
    );
  }
}
