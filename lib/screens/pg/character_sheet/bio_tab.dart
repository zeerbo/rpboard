import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/character.dart';
import 'shared_widgets.dart';

/// Bio tab: personality traits, ideals, bonds, flaws, features/talents,
/// languages, backstory, and appearance/physical fields.
///
/// "Linguaggi" and "Caratteristiche e Talenti" are edited as lists of
/// individual entries (add/remove, no reorder). Each entry owns its own
/// [TextEditingController](s), created when the entry is added and disposed
/// when it is removed, kept index-aligned with `character.languages` /
/// `character.features`.
class BioTab extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const BioTab({super.key, required this.character, required this.onChanged});

  @override
  State<BioTab> createState() => _BioTabState();
}

class _BioTabState extends State<BioTab> {
  late final TextEditingController _personalityTraits;
  late final TextEditingController _ideals;
  late final TextEditingController _bonds;
  late final TextEditingController _flaws;
  late final TextEditingController _backstory;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _eyes;
  late final TextEditingController _skin;
  late final TextEditingController _hair;
  late final TextEditingController _appearance;

  // One controller per language entry, index-aligned with character.languages.
  final List<TextEditingController> _languageCtrls = [];
  // One title + one description controller per feature entry, both
  // index-aligned with character.features.
  final List<TextEditingController> _featureTitleCtrls = [];
  final List<TextEditingController> _featureDescCtrls = [];

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _personalityTraits = TextEditingController(text: c.personalityTraits);
    _ideals = TextEditingController(text: c.ideals);
    _bonds = TextEditingController(text: c.bonds);
    _flaws = TextEditingController(text: c.flaws);
    _backstory = TextEditingController(text: c.backstory);
    _age = TextEditingController(text: c.age > 0 ? c.age.toString() : '');
    _height = TextEditingController(text: c.height);
    _weight = TextEditingController(text: c.weight);
    _eyes = TextEditingController(text: c.eyes);
    _skin = TextEditingController(text: c.skin);
    _hair = TextEditingController(text: c.hair);
    _appearance = TextEditingController(text: c.appearance);
    for (final l in c.languages) {
      _languageCtrls.add(TextEditingController(text: l));
    }
    for (final f in c.features) {
      _featureTitleCtrls.add(TextEditingController(text: f.title));
      _featureDescCtrls.add(TextEditingController(text: f.description));
    }
  }

  @override
  void dispose() {
    _personalityTraits.dispose();
    _ideals.dispose();
    _bonds.dispose();
    _flaws.dispose();
    _backstory.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _eyes.dispose();
    _skin.dispose();
    _hair.dispose();
    _appearance.dispose();
    for (final ctrl in _languageCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _featureTitleCtrls) {
      ctrl.dispose();
    }
    for (final ctrl in _featureDescCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _edit(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  // A text edit mutates the model in place and persists, but must not
  // setState — rebuilding the field mid-keystroke is unnecessary and the
  // controller already holds the visible text.
  void _persist() => widget.onChanged();

  void _addLanguage() => _edit(() {
        widget.character.languages.add('');
        _languageCtrls.add(TextEditingController());
      });

  void _removeLanguage(int i) => _edit(() {
        widget.character.languages.removeAt(i);
        _languageCtrls.removeAt(i).dispose();
      });

  void _addFeature() => _edit(() {
        widget.character.features.add(CharacterFeature());
        _featureTitleCtrls.add(TextEditingController());
        _featureDescCtrls.add(TextEditingController());
      });

  void _removeFeature(int i) => _edit(() {
        widget.character.features.removeAt(i);
        _featureTitleCtrls.removeAt(i).dispose();
        _featureDescCtrls.removeAt(i).dispose();
      });

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Tratti del Personaggio'),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _personalityTraits,
            label: 'Tratti della Personalità',
            multiline: true,
            onEdited: (v) => _edit(() => c.personalityTraits = v),
          ),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _ideals,
            label: 'Ideali',
            multiline: true,
            onEdited: (v) => _edit(() => c.ideals = v),
          ),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _bonds,
            label: 'Legami',
            multiline: true,
            onEdited: (v) => _edit(() => c.bonds = v),
          ),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _flaws,
            label: 'Difetti',
            multiline: true,
            onEdited: (v) => _edit(() => c.flaws = v),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Linguaggi'),
          const SizedBox(height: 8),
          _buildLanguages(c),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Caratteristiche e Talenti'),
          const SizedBox(height: 8),
          _buildFeatures(c),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Retroscena'),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _backstory,
            label: 'Storia del Personaggio',
            multiline: true,
            onEdited: (v) => _edit(() => c.backstory = v),
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Aspetto Fisico'),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 70,
              child: SheetTextField(
                controller: _age,
                label: 'Età',
                numeric: true,
                onEdited: (v) => _edit(() => c.age = int.tryParse(v) ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _height,
                label: 'Altezza',
                onEdited: (v) => _edit(() => c.height = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _weight,
                label: 'Peso',
                onEdited: (v) => _edit(() => c.weight = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SheetTextField(
                controller: _eyes,
                label: 'Occhi',
                onEdited: (v) => _edit(() => c.eyes = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _skin,
                label: 'Carnagione',
                onEdited: (v) => _edit(() => c.skin = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SheetTextField(
                controller: _hair,
                label: 'Capelli',
                onEdited: (v) => _edit(() => c.hair = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _appearance,
            label: 'Descrizione Aspetto',
            multiline: true,
            onEdited: (v) => _edit(() => c.appearance = v),
          ),
        ],
      ),
    );
  }

  /// Linguaggi: one full-width text box per language plus a remove icon, then
  /// an "aggiungi" button. Order is insertion order (no reorder).
  Widget _buildLanguages(Character c) {
    return Column(
      children: [
        if (c.languages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Nessun linguaggio',
                  style:
                      TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            ),
          ),
        for (int i = 0; i < c.languages.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: SheetTextField(
                    controller: _languageCtrls[i],
                    label: 'Linguaggio',
                    onEdited: (v) {
                      c.languages[i] = v;
                      _persist();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.danger),
                  onPressed: () => _removeLanguage(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addLanguage,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi Linguaggio'),
          ),
        ),
      ],
    );
  }

  /// Caratteristiche e Talenti: one bordered card per entry — a single-line
  /// title box, a multiline description below, and a remove icon — then an
  /// "aggiungi" button. Order is insertion order (no reorder).
  Widget _buildFeatures(Character c) {
    return Column(
      children: [
        if (c.features.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Nessuna caratteristica',
                  style:
                      TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12)),
            ),
          ),
        for (int i = 0; i < c.features.length; i++)
          Card(
            color: AppTheme.surfaceVariant,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SheetTextField(
                          controller: _featureTitleCtrls[i],
                          label: 'Nome',
                          onEdited: (v) {
                            c.features[i].title = v;
                            _persist();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.danger),
                        onPressed: () => _removeFeature(i),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SheetTextField(
                      controller: _featureDescCtrls[i],
                      label: 'Descrizione',
                      multiline: true,
                      onEdited: (v) {
                        c.features[i].description = v;
                        _persist();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addFeature,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi Caratteristica'),
          ),
        ),
      ],
    );
  }
}
