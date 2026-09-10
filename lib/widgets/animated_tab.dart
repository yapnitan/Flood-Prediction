import 'package:flutter/material.dart';

class AnimatedTab extends StatelessWidget {
  const AnimatedTab({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(index), child: child),
    );
  }
}
