import 'package:flutter/material.dart';

/// Colored pill showing a repair_request priority value. Mirrors
/// [StatusBadge]'s look so priority reads as an equally first-class signal
/// wherever a request is listed, not just text buried in a detail screen.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority, this.dense = false});

  final String priority;

  /// Smaller padding/font for tight list rows (e.g. task cards).
  final bool dense;

  static const Map<String, Color> _colors = {
    'urgent': Colors.red,
    'high': Colors.orange,
    'medium': Colors.blue,
    'low': Colors.grey,
  };

  static Color colorFor(String priority) => _colors[priority] ?? Colors.blue;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(priority);
    final label = priority.isEmpty
        ? 'Medium'
        : priority[0].toUpperCase() + priority.substring(1);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: dense ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
