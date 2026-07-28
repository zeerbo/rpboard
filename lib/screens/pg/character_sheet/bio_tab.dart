import 'package:flutter/material.dart';
import '../../../models/character.dart';
import 'shared_widgets.dart';

/// Bio tab: personality traits, ideals, bonds, flaws, features,
/// proficiencies/languages, backstory, and appearance/physical fields.
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
  late final TextEditingController _featuresAndTraits;
  late final TextEditingController _profsAndLanguages;
  late final TextEditingController _backstory;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _eyes;
  late final TextEditingController _skin;
  late final TextEditingController _hair;
  late final TextEditingController _appearance;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _personalityTraits = TextEditingController(text: c.personalityTraits);
    _ideals = TextEditingController(text: c.ideals);
    _bonds = TextEditingController(text: c.bonds);
    _flaws = TextEditingController(text: c.flaws);
    _featuresAndTraits = TextEditingController(text: c.featuresAndTraits);
    _profsAndLanguages = TextEditingController(text: c.profsAndLanguages);
    _backstory = TextEditingController(text: c.backstory);
    _age = TextEditingController(text: c.age > 0 ? c.age.toString() : '');
    _height = TextEditingController(text: c.height);
    _weight = TextEditingController(text: c.weight);
    _eyes = TextEditingController(text: c.eyes);
    _skin = TextEditingController(text: c.skin);
    _hair = TextEditingController(text: c.hair);
    _appearance = TextEditingController(text: c.appearance);
  }

  @override
  void dispose() {
    _personalityTraits.dispose();
    _ideals.dispose();
    _bonds.dispose();
    _flaws.dispose();
    _featuresAndTraits.dispose();
    _profsAndLanguages.dispose();
    _backstory.dispose();
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _eyes.dispose();
    _skin.dispose();
    _hair.dispose();
    _appearance.dispose();
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
          const SectionHeader(title: 'Caratteristiche e Talenti'),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _featuresAndTraits,
            label: 'Caratteristiche e Talenti',
            multiline: true,
            onEdited: (v) => _edit(() => c.featuresAndTraits = v),
          ),
          const SizedBox(height: 8),
          SheetTextField(
            controller: _profsAndLanguages,
            label: 'Competenze e Lingue',
            multiline: true,
            onEdited: (v) => _edit(() => c.profsAndLanguages = v),
          ),
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
}
