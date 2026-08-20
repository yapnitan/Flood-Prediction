import 'package:flutter/material.dart';

/// Light-touch fade between bottom-nav/rail tabs that already fully rebuild
/// on switch (i.e. aren't kept alive in an `IndexedStack` — where a fade
/// would fight that widget's own state-preservation). [index] must change
/// whenever [child] does, so `AnimatedSwitcher` treats it as a new child
/// worth transitioning to rather than an in-place update.
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
