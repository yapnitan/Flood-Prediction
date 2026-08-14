import 'package:flutter/material.dart';

const String kAddNewValue = '__add_new__';

DropdownMenuItem<String> addNewMenuItem(String label) {
  return DropdownMenuItem(
    value: kAddNewValue,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.add_circle_outline, size: 16, color: Colors.blue),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
