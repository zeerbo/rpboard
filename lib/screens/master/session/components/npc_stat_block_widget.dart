import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/component.dart';

class NpcStatBlockWidget extends StatefulWidget {
  final SessionComponent component;
  final bool isEditMode;
  final Future<void> Function(SessionComponent) onUpdate;

  const NpcStatBlockWidget({
    super.key,
    required this.component,
    required this.isEditMode,
    required this.onUpdate,
  });

  @override
  State<NpcStatBlockWidget> createState() => _NpcStatBlockWidgetState();
}

class _NpcStatBlockWidgetState extends State<NpcStatBlockWidget> {
  bool _expanded = false;

  NpcStatBlockData get _typedData => widget.component.data as NpcStatBlockData;

  @override
  Widget build(BuildContext context) {
    final d = _typedData;
    final name = d.name.isEmpty ? 'NPC' : d.name;
    final size = d.size;
    final type = d.type;
    final alignment = d.alignment;
    final ac = d.ac;
    final acType = d.acType;
    final hp = d.hp;
    final speed = d.speed;
    final cr = d.cr;

    final str = d.str;
    final dex = d.dex;
    final con = d.con;
    final intS = d.int_;
    final wis = d.wis;
    final cha = d.cha;

    final senses = d.senses;
    final languages = d.languages;
    final notes = d.notes;

    final traits = _parseAbilities(d.traits);
    final actions = _parseAbilities(d.actions);
    final bonusActions = _parseAbilities(d.bonusActions);
    final reactions = _parseAbilities(d.reactions);
    final legendaryActions = _parseAbilities(d.legendaryActions);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a0a0a),
        border: Border.all(color: const Color(0xFF8b0000), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF8b0000),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (size.isNotEmpty || type.isNotEmpty || alignment.isNotEmpty)
                        Text(
                          [size, type, alignment].where((s) => s.isNotEmpty).join(', '),
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                if (widget.isEditMode)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                    onPressed: () => _showEditDialog(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Combat stats
                _RedDivider(),
                _StatLine('CA', '$ac${acType.isNotEmpty ? " ($acType)" : ""}'),
                _StatLine('PF', hp),
                _StatLine('Velocità', speed),
                _RedDivider(),
                // Ability scores
                _AbilityScoreRow(str: str, dex: dex, con: con, int_: intS, wis: wis, cha: cha),
                _RedDivider(),
                // Other stats
                if (d.savingThrows.isNotEmpty)
                  _StatLine('Tiri Salvezza', d.savingThrows),
                if (d.skills.isNotEmpty)
                  _StatLine('Abilità', d.skills),
                if (d.damageResistances.isNotEmpty)
                  _StatLine('Resistenze', d.damageResistances),
                if (d.damageImmunities.isNotEmpty)
                  _StatLine('Immunità', d.damageImmunities),
                if (d.conditionImmunities.isNotEmpty)
                  _StatLine('Immunità Condizioni', d.conditionImmunities),
                if (senses.isNotEmpty) _StatLine('Sensi', senses),
                if (languages.isNotEmpty) _StatLine('Lingue', languages),
                _StatLine('Grado Sfida', '$cr${_xpForCr(cr)}'),
                // Expandable sections
                if (traits.isNotEmpty || actions.isNotEmpty || bonusActions.isNotEmpty || reactions.isNotEmpty || legendaryActions.isNotEmpty) ...[
                  _RedDivider(),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        const Text('ABILITÀ E AZIONI', style: TextStyle(color: Color(0xFF8b0000), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                        const Spacer(),
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: const Color(0xFF8b0000), size: 18),
                      ],
                    ),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 8),
                    if (traits.isNotEmpty) ...[
                      _AbilitySection(title: 'Tratti', abilities: traits),
                      const SizedBox(height: 8),
                    ],
                    if (actions.isNotEmpty) ...[
                      _AbilitySection(title: 'Azioni', abilities: actions),
                      const SizedBox(height: 8),
                    ],
                    if (bonusActions.isNotEmpty) ...[
                      _AbilitySection(title: 'Azioni Bonus', abilities: bonusActions),
                      const SizedBox(height: 8),
                    ],
                    if (reactions.isNotEmpty) ...[
                      _AbilitySection(title: 'Reazioni', abilities: reactions),
                      const SizedBox(height: 8),
                    ],
                    if (legendaryActions.isNotEmpty)
                      _AbilitySection(title: 'Azioni Leggendarie', abilities: legendaryActions),
                  ],
                ],
                if (notes.isNotEmpty) ...[
                  _RedDivider(),
                  Text(notes, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _parseAbilities(List<Map<String, dynamic>> raw) {
    try {
      return raw.map((e) => Map<String, String>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  String _xpForCr(String cr) {
    const xp = {
      '0': '', '1/8': ' (25 XP)', '1/4': ' (50 XP)', '1/2': ' (100 XP)',
      '1': ' (200 XP)', '2': ' (450 XP)', '3': ' (700 XP)', '4': ' (1.100 XP)',
      '5': ' (1.800 XP)', '6': ' (2.300 XP)', '7': ' (2.900 XP)', '8': ' (3.900 XP)',
      '9': ' (5.000 XP)', '10': ' (5.900 XP)', '11': ' (7.200 XP)', '12': ' (8.400 XP)',
      '13': ' (10.000 XP)', '14': ' (11.500 XP)', '15': ' (13.000 XP)', '16': ' (15.000 XP)',
      '17': ' (18.000 XP)', '18': ' (20.000 XP)', '19': ' (22.000 XP)', '20': ' (25.000 XP)',
    };
    return xp[cr] ?? '';
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final d = _typedData;

    final ctrls = <String, TextEditingController>{
      'name': TextEditingController(text: d.name),
      'size': TextEditingController(text: d.size),
      'type': TextEditingController(text: d.type),
      'alignment': TextEditingController(text: d.alignment),
      'ac': TextEditingController(text: d.ac.toString()),
      'acType': TextEditingController(text: d.acType),
      'hp': TextEditingController(text: d.hp),
      'speed': TextEditingController(text: d.speed),
      'str': TextEditingController(text: d.str.toString()),
      'dex': TextEditingController(text: d.dex.toString()),
      'con': TextEditingController(text: d.con.toString()),
      'int': TextEditingController(text: d.int_.toString()),
      'wis': TextEditingController(text: d.wis.toString()),
      'cha': TextEditingController(text: d.cha.toString()),
      'savingThrows': TextEditingController(text: d.savingThrows),
      'skills': TextEditingController(text: d.skills),
      'damageResistances': TextEditingController(text: d.damageResistances),
      'damageImmunities': TextEditingController(text: d.damageImmunities),
      'conditionImmunities': TextEditingController(text: d.conditionImmunities),
      'senses': TextEditingController(text: d.senses),
      'languages': TextEditingController(text: d.languages),
      'cr': TextEditingController(text: d.cr),
      'traits': TextEditingController(text: _abilitiesToText(d.traits)),
      'actions': TextEditingController(text: _abilitiesToText(d.actions)),
      'bonusActions': TextEditingController(text: _abilitiesToText(d.bonusActions)),
      'reactions': TextEditingController(text: _abilitiesToText(d.reactions)),
      'legendaryActions': TextEditingController(text: _abilitiesToText(d.legendaryActions)),
      'notes': TextEditingController(text: d.notes),
    };

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 600,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Modifica NPC', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _tf(ctrls['name']!, 'Nome'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _tf(ctrls['size']!, 'Taglia')),
                          const SizedBox(width: 8),
                          Expanded(child: _tf(ctrls['type']!, 'Tipo')),
                          const SizedBox(width: 8),
                          Expanded(child: _tf(ctrls['alignment']!, 'Allineamento')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _tf(ctrls['ac']!, 'CA', numeric: true)),
                          const SizedBox(width: 8),
                          Expanded(child: _tf(ctrls['acType']!, 'Tipo CA')),
                          const SizedBox(width: 8),
                          Expanded(child: _tf(ctrls['hp']!, 'PF (es. 7 (2d6))')),
                          const SizedBox(width: 8),
                          Expanded(child: _tf(ctrls['speed']!, 'Velocità')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _tf(ctrls['str']!, 'FOR', numeric: true)),
                          const SizedBox(width: 4),
                          Expanded(child: _tf(ctrls['dex']!, 'DES', numeric: true)),
                          const SizedBox(width: 4),
                          Expanded(child: _tf(ctrls['con']!, 'COS', numeric: true)),
                          const SizedBox(width: 4),
                          Expanded(child: _tf(ctrls['int']!, 'INT', numeric: true)),
                          const SizedBox(width: 4),
                          Expanded(child: _tf(ctrls['wis']!, 'SAG', numeric: true)),
                          const SizedBox(width: 4),
                          Expanded(child: _tf(ctrls['cha']!, 'CAR', numeric: true)),
                        ]),
                        const SizedBox(height: 8),
                        _tf(ctrls['savingThrows']!, 'Tiri Salvezza'),
                        const SizedBox(height: 8),
                        _tf(ctrls['skills']!, 'Abilità'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _tf(ctrls['damageResistances']!, 'Resistenze')),
                          const SizedBox(width: 8),
                          Expanded(child: _tf(ctrls['damageImmunities']!, 'Immunità Danni')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _tf(ctrls['conditionImmunities']!, 'Immunità Condizioni')),
                          const SizedBox(width: 8),
                          Expanded(child: _tf(ctrls['senses']!, 'Sensi')),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _tf(ctrls['languages']!, 'Lingue')),
                          const SizedBox(width: 8),
                          SizedBox(width: 80, child: _tf(ctrls['cr']!, 'GS')),
                        ]),
                        const SizedBox(height: 8),
                        const Align(alignment: Alignment.centerLeft, child: Text('Tratti (Nome: descrizione — una per riga)', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11))),
                        _tf(ctrls['traits']!, 'Tratti', multiline: true),
                        const SizedBox(height: 8),
                        const Align(alignment: Alignment.centerLeft, child: Text('Azioni (Nome: descrizione — una per riga)', style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 11))),
                        _tf(ctrls['actions']!, 'Azioni', multiline: true),
                        const SizedBox(height: 8),
                        _tf(ctrls['bonusActions']!, 'Azioni Bonus', multiline: true),
                        const SizedBox(height: 8),
                        _tf(ctrls['reactions']!, 'Reazioni', multiline: true),
                        const SizedBox(height: 8),
                        _tf(ctrls['legendaryActions']!, 'Azioni Leggendarie', multiline: true),
                        const SizedBox(height: 8),
                        _tf(ctrls['notes']!, 'Note', multiline: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        d.name = ctrls['name']!.text;
                        d.size = ctrls['size']!.text;
                        d.type = ctrls['type']!.text;
                        d.alignment = ctrls['alignment']!.text;
                        d.ac = int.tryParse(ctrls['ac']!.text) ?? 10;
                        d.acType = ctrls['acType']!.text;
                        d.hp = ctrls['hp']!.text;
                        d.speed = ctrls['speed']!.text;
                        d.str = int.tryParse(ctrls['str']!.text) ?? 10;
                        d.dex = int.tryParse(ctrls['dex']!.text) ?? 10;
                        d.con = int.tryParse(ctrls['con']!.text) ?? 10;
                        d.int_ = int.tryParse(ctrls['int']!.text) ?? 10;
                        d.wis = int.tryParse(ctrls['wis']!.text) ?? 10;
                        d.cha = int.tryParse(ctrls['cha']!.text) ?? 10;
                        d.savingThrows = ctrls['savingThrows']!.text;
                        d.skills = ctrls['skills']!.text;
                        d.damageResistances = ctrls['damageResistances']!.text;
                        d.damageImmunities = ctrls['damageImmunities']!.text;
                        d.conditionImmunities = ctrls['conditionImmunities']!.text;
                        d.senses = ctrls['senses']!.text;
                        d.languages = ctrls['languages']!.text;
                        d.cr = ctrls['cr']!.text;
                        d.traits = _textToAbilities(ctrls['traits']!.text);
                        d.actions = _textToAbilities(ctrls['actions']!.text);
                        d.bonusActions = _textToAbilities(ctrls['bonusActions']!.text);
                        d.reactions = _textToAbilities(ctrls['reactions']!.text);
                        d.legendaryActions = _textToAbilities(ctrls['legendaryActions']!.text);
                        d.notes = ctrls['notes']!.text;
                        widget.onUpdate(widget.component);
                        Navigator.pop(context);
                      },
                      child: const Text('Salva'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final ctrl in ctrls.values) ctrl.dispose();
  }

  String _abilitiesToText(List<Map<String, dynamic>> raw) {
    try {
      return raw.map((m) => '${m['name']}: ${m['desc']}').join('\n');
    } catch (_) {
      return '';
    }
  }

  List<Map<String, String>> _textToAbilities(String text) {
    if (text.trim().isEmpty) return [];
    return text.split('\n').where((l) => l.trim().isNotEmpty).map((line) {
      final idx = line.indexOf(':');
      if (idx < 0) return {'name': line.trim(), 'desc': ''};
      return {'name': line.substring(0, idx).trim(), 'desc': line.substring(idx + 1).trim()};
    }).toList();
  }

  Widget _tf(TextEditingController ctrl, String label, {bool numeric = false, bool multiline = false}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLines: multiline ? null : 1,
      minLines: multiline ? 2 : null,
    );
  }
}

// Displays a simple stat line like "CA 15"
class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(text: '$label ', style: const TextStyle(color: Color(0xFF8b0000), fontWeight: FontWeight.bold, fontSize: 13)),
              TextSpan(text: value, style: const TextStyle(color: AppTheme.onSurface, fontSize: 13)),
            ],
          ),
        ),
      );
}

class _RedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Divider(color: Color(0xFF8b0000), thickness: 1),
      );
}

class _AbilityScoreRow extends StatelessWidget {
  final int str, dex, con, int_, wis, cha;

  const _AbilityScoreRow({
    required this.str,
    required this.dex,
    required this.con,
    required this.int_,
    required this.wis,
    required this.cha,
  });

  int _mod(int score) => ((score - 10) / 2).floor();
  String _fmt(int score) {
    final m = _mod(score);
    return '$score (${m >= 0 ? "+$m" : "$m"})';
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['FOR', 'DES', 'COS', 'INT', 'SAG', 'CAR'];
    final values = [str, dex, con, int_, wis, cha];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(6, (i) => Column(
        children: [
          Text(labels[i], style: const TextStyle(color: Color(0xFF8b0000), fontWeight: FontWeight.bold, fontSize: 11)),
          Text(_fmt(values[i]), style: const TextStyle(color: AppTheme.onSurface, fontSize: 11)),
        ],
      )),
    );
  }
}

class _AbilitySection extends StatelessWidget {
  final String title;
  final List<Map<String, String>> abilities;

  const _AbilitySection({required this.title, required this.abilities});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF8b0000), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 4),
          ...abilities.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: '${a['name'] ?? ''}. ', style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12, fontStyle: FontStyle.italic)),
                  TextSpan(text: a['desc'] ?? '', style: const TextStyle(color: AppTheme.onSurface, fontSize: 12)),
                ],
              ),
            ),
          )),
        ],
      );
}
