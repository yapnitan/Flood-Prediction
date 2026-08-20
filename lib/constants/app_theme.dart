import 'package:flutter/material.dart';

/// App-wide color palette and [ThemeData]. Centralizes the colors that were
/// previously repeated as `Colors.blue`/`Colors.red`/etc. literals across
/// individual views — new screens should reference [AppTheme] instead of
/// hardcoding a `Colors.*` value. Existing one-off literals that happen to
/// already match these (e.g. `StatusBadge`/`PriorityBadge`'s own semantic
/// color maps) are left as-is; this isn't a full-app color-literal sweep.
class AppTheme {
  const AppTheme._();

  /// Brand primary — used for the app bar accent, primary buttons, and
  /// links across every role's dashboard.
  static const Color primary = Colors.blue;

  /// Role accents, matching what user_management_view.dart already uses to
  /// color-code accounts by role.
  static const Color adminAccent = Colors.purple;
  static const Color helperAccent = Colors.teal;
  static const Color userAccent = Colors.blue;

  /// Status/semantic colors shared by StatusBadge/PriorityBadge's palettes.
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color danger = Colors.red;
  static const Color info = Colors.indigo;

  static const Color scaffoldBackground = Colors.white;
  static const Color listBackground = Color(0xFFF4F7FC);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: primary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: primary),
        selectedLabelTextStyle: TextStyle(color: primary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? success : null,
        ),
      ),
    );
  }
}
