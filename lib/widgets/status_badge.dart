import 'package:flutter/material.dart';

/// Colored pill showing a repair_request status value.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  static const Map<String, Color> _colors = {
    'pending': Colors.orange,
    'approved': Colors.teal,
    'rejected': Colors.red,
    'assigned': Colors.blue,
    'in_progress': Colors.indigo,
    'completed': Colors.green,
    'cancelled': Colors.grey,
  };

  static const Map<String, String> _labels = {
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
    'assigned': 'Assigned',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? Colors.grey;
    final label = _labels[status] ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}