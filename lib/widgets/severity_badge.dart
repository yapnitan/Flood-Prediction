import 'package:flutter/material.dart';

/// Colored pill for a Structural Repair request's `details['severity']`
/// (see assistance_field_spec.dart's 'Structural Repair' spec) — surfaced
/// next to [PriorityBadge] on list cards so damage severity reads as an
/// equally first-class triage signal, not something buried in the detail
/// page's field list.
class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity, this.dense = false});

  final String severity;
  final bool dense;

  static const Map<String, Color> _colors = {
    'Minor': Colors.blue,
    'Moderate': Colors.orange,
    'Severe': Colors.deepOrange,
    'Total loss': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[severity] ?? Colors.grey;

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
          Icon(Icons.report_gmailerrorred, size: dense ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              severity,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
