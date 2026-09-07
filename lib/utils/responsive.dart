import 'package:flutter/material.dart';

/// Screen width breakpoints used across the app.
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

/// Carries the root view's keyboard state below nested [Scaffold] widgets.
///
/// A scaffold that resizes for the keyboard removes the consumed bottom
/// inset from its descendants' [MediaQuery]. Reading the inset only inside a
/// nested tab would therefore incorrectly report that the keyboard is closed.
class KeyboardVisibilityScope extends InheritedWidget {
  const KeyboardVisibilityScope({
    super.key,
    required this.visible,
    required super.child,
  });

  final bool visible;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KeyboardVisibilityScope>();
    return scope?.visible ?? MediaQuery.viewInsetsOf(context).bottom > 0;
  }

  @override
  bool updateShouldNotify(KeyboardVisibilityScope oldWidget) =>
      visible != oldWidget.visible;
}

/// Adds responsive helpers to [BuildContext] so views can adapt
/// padding, sizing and layout to the current screen width.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Uses the root system-reported inset instead of assuming a device size,
  /// orientation, or keyboard height.
  bool get isKeyboardVisible => KeyboardVisibilityScope.of(this);

  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.tablet;

  /// Picks a value based on the current screen width, falling back to
  /// [mobile] when a wider variant isn't provided.
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}
