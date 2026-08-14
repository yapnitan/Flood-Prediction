import 'package:flutter/material.dart';
import '../models/assistance_field_spec.dart';
import 'selectable_chip.dart';

class DynamicAssistanceFields extends StatelessWidget {
  const DynamicAssistanceFields({
    super.key,
    required this.assistanceType,
    required this.values,
    required this.onChanged,
  });

  final String assistanceType;
  final Map<String, dynamic> values;
  final void Function(String key, dynamic value) onChanged;

  static List<String> missingRequiredLabels(String assistanceType, Map<String, dynamic> values) {
    final fields = assistanceFieldSpecs[assistanceType] ?? const [];
    final missing = <String>[];
    for (final field in fields) {
      if (!field.required) continue;
      final value = values[field.key];
      final isEmpty = value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);
      if (isEmpty) missing.add(field.label);
    }
    return missing;
  }

  @override
  Widget build(BuildContext context) {
    final fields = assistanceFieldSpecs[assistanceType] ?? const [];
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields
          .map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildField(field),
              ))
          .toList(),
    );
  }

  Widget _buildField(AssistanceField field) {
    switch (field.type) {
      case AssistanceFieldType.text:
        return TextFormField(
          initialValue: values[field.key] as String? ?? '',
          decoration: InputDecoration(
            labelText: field.required ? '${field.label} *' : field.label,
            hintText: field.hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => onChanged(field.key, v),
        );

      case AssistanceFieldType.multiline:
        return TextFormField(
          initialValue: values[field.key] as String? ?? '',
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: field.required ? '${field.label} *' : field.label,
            hintText: field.hint,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => onChanged(field.key, v),
        );

      case AssistanceFieldType.number:
        return TextFormField(
          initialValue: values[field.key]?.toString() ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: field.required ? '${field.label} *' : field.label,
            hintText: field.hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => onChanged(field.key, num.tryParse(v)),
        );

      case AssistanceFieldType.dropdown:
        final current = values[field.key] as String?;
        return DropdownButtonFormField<String>(
          initialValue: field.options.contains(current) ? current : null,
          decoration: InputDecoration(
            labelText: field.required ? '${field.label} *' : field.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: field.options
              .map((option) => DropdownMenuItem(value: option, child: Text(option)))
              .toList(),
          onChanged: (v) => onChanged(field.key, v),
        );

      case AssistanceFieldType.multiSelect:
        final selected = (values[field.key] as List?)?.cast<String>() ?? const <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.required ? '${field.label} *' : field.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: field.options.map((option) {
                final isSelected = selected.contains(option);
                return SelectableChip(
                  label: option,
                  selected: isSelected,
                  onTap: () {
                    final updated = [...selected];
                    if (isSelected) {
                      updated.remove(option);
                    } else {
                      updated.add(option);
                    }
                    onChanged(field.key, updated);
                  },
                );
              }).toList(),
            ),
          ],
        );

      case AssistanceFieldType.checkbox:
        final checked = values[field.key] == true;
        final isCritical = field.key == 'is_critical';
        return Container(
          decoration: isCritical
              ? BoxDecoration(
                  color: checked ? Colors.red.shade50 : null,
                  border: Border.all(color: checked ? Colors.red.shade300 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: CheckboxListTile(
            value: checked,
            onChanged: (v) => onChanged(field.key, v ?? false),
            title: Text(field.label, style: isCritical ? TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600) : null),
            subtitle: field.hint != null ? Text(field.hint!) : null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: isCritical ? Colors.red : null,
          ),
        );
    }
  }
}
