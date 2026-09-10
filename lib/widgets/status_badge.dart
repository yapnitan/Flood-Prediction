import 'package:flutter/material.dart';

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
    'submitted': Colors.blue,
    'verified': Colors.teal,
    'resolved': Colors.green,
    'pending_review': Colors.orange,
    'helper_verified': Colors.blue,
  };

  static const Map<String, String> _labels = {
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
    'assigned': 'Assigned',
    'in_progress': 'In Progress',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    'submitted': 'Submitted',
    'verified': 'Verified',
    'resolved': 'Resolved',
    'pending_review': 'Pending Review',
    'helper_verified': 'Helper Verified',
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
