import 'package:flutter/material.dart';
import '../../../models/character.dart';

/// Note tab: a single free-text notes field.
class NoteTab extends StatefulWidget {
  final Character character;
  final VoidCallback onChanged;

  const NoteTab({super.key, required this.character, required this.onChanged});

  @override
  State<NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends State<NoteTab> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.character.notes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _notes,
        decoration: const InputDecoration(
          labelText: 'Note',
          alignLabelWithHint: true,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: (v) {
          widget.character.notes = v;
          widget.onChanged();
        },
      ),
    );
  }
}
