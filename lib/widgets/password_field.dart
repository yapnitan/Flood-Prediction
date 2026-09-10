import 'package:flutter/material.dart';

/// Password [TextField] with a leading lock icon, a trailing show/hide eye
/// toggle, and an [errorText] slot — Flutter renders that directly beneath
/// the field, so every password field in the app shows its own error in the
/// same place instead of one combined message above the form.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon = Icons.lock,
    this.errorText,
    this.bold = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData prefixIcon;
  final String? errorText;

  /// Matches the bold label/input text styling used on the Login and
  /// Register screens; other screens use the plain default style.
  final bool bold;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      onChanged: widget.onChanged,
      style: widget.bold
          ? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)
          : null,
      decoration: InputDecoration(
        labelText: widget.labelText,
        labelStyle: widget.bold
            ? const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)
            : null,
        hintText: widget.hintText,
        hintStyle: widget.bold ? const TextStyle(color: Colors.grey, fontSize: 14) : null,
        errorText: widget.errorText,
        errorMaxLines: 2,
        prefixIcon: Icon(widget.prefixIcon, color: Colors.blue),
        suffixIcon: IconButton(
          // Icon reflects the current state: crossed-out eye while the
          // password is hidden, open eye while it's visible.
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          color: Colors.grey,
          tooltip: _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
