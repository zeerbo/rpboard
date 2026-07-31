import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// Small uppercase section label used across every Character sheet tab.
class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.accent,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
      );
}

/// Small labeled value chip (e.g. "Bonus Competenza +2") used on the Info
/// and Magie tabs.
class InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const InfoChip(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 10)),
          ],
        ),
      );
}

/// A field-editing helper shared by every tab that owns free-text
/// [TextEditingController]s: renders a [TextField] bound to [controller] and
/// writes through into the model by calling [onEdited] with the new text.
class SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final bool multiline;
  final bool numeric;
  final ValueChanged<String> onEdited;

  const SheetTextField({
    super.key,
    required this.controller,
    required this.onEdited,
    this.label,
    this.multiline = false,
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        maxLines: multiline ? null : 1,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))]
            : null,
        onChanged: onEdited,
      );
}

/// Compact badge next to a field affected by equipment, e.g. "10 → 12 (+2
/// equip.)". Renders nothing when [base] == [effective] (no equipment
/// share), so callers can include it unconditionally.
class EquipmentBadge extends StatelessWidget {
  final int base;
  final int effective;
  const EquipmentBadge({super.key, required this.base, required this.effective});

  @override
  Widget build(BuildContext context) {
    final equip = effective - base;
    if (equip == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Text(
        '$base → $effective (${equip >= 0 ? "+" : ""}$equip equip.)',
        style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String fmtMod(int mod) => mod >= 0 ? '+$mod' : '$mod';

String abilityShort(String a) {
  switch (a) {
    case 'str': return 'FOR';
    case 'dex': return 'DES';
    case 'con': return 'COS';
    case 'int': return 'INT';
    case 'wis': return 'SAG';
    case 'cha': return 'CAR';
    default: return a.toUpperCase();
  }
}
