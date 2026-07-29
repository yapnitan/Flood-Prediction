import 'package:flutter/material.dart';

/// Screen width breakpoints used across the app.
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

/// Adds responsive helpers to [BuildContext] so views can adapt
/// padding, sizing and layout to the current screen width.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

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
