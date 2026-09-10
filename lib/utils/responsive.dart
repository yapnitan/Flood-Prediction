import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

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

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  bool get isKeyboardVisible => KeyboardVisibilityScope.of(this);

  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.tablet;

  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }
}
