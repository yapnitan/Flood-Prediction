import 'package:flutter/material.dart';
import '../models/assistance_field_spec.dart';
import 'review_card.dart';

class AssistanceDetailsView extends StatelessWidget {
  const AssistanceDetailsView({
    super.key,
    required this.assistanceType,
    required this.details,
  });

  final String assistanceType;
  final Map<String, dynamic> details;

  @override
  Widget build(BuildContext context) {
    final fields = assistanceFieldSpecs[assistanceType] ?? const [];
    final rows = <Widget>[];

    final isCritical = details['is_critical'] == true;
    if (isCritical) {
      rows.add(Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Critical case — this patient needs urgent attention.',
                style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ));
    }

    for (final field in fields) {
      if (field.key == 'is_critical') continue; // shown as the banner above
      final formatted = _formatValue(field, details[field.key]);
      if (formatted == null) continue;
      rows.add(ReviewCard(title: field.label.replaceAll(' (optional)', ''), value: formatted));
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  String? _formatValue(AssistanceField field, dynamic value) {
    if (value == null) return null;
    switch (field.type) {
      case AssistanceFieldType.checkbox:
        return value == true ? 'Yes' : null; // unchecked boxes aren't worth a row
      case AssistanceFieldType.multiSelect:
        final list = (value as List?)?.cast<String>() ?? const [];
        return list.isEmpty ? null : list.join(', ');
      case AssistanceFieldType.text:
      case AssistanceFieldType.multiline:
        final text = value.toString().trim();
        return text.isEmpty ? null : text;
      case AssistanceFieldType.number:
        return value.toString();
      case AssistanceFieldType.dropdown:
        final text = value.toString().trim();
        return text.isEmpty ? null : text;
    }
  }
}
