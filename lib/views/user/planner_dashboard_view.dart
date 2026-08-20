import 'package:flutter/material.dart';

import '../../controllers/planner_controller.dart';
import '../../routes/app_routes.dart';
import '../../services/notification_service.dart';
import '../../services/planner_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/offline_banner.dart';

/// Module 3 entry point (CLAUDE.md Task 8) — preparation progress plus
/// cards into Checklist, Inventory, Emergency Contacts, and the Nearby PPS
/// map.
class PlannerDashboardView extends StatefulWidget {
  const PlannerDashboardView({super.key});

  @override
  State<PlannerDashboardView> createState() => _PlannerDashboardViewState();
}

class _PlannerDashboardViewState extends State<PlannerDashboardView> {
  final _controller = PlannerController(PlannerService());
  late Future<double> _progressFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final future = _controller.getPreparationProgress();
    setState(() => _progressFuture = future);
    future.then(_syncChecklistReminder);
  }

  /// Task 9 "reminder notifications" — keeps a daily local reminder armed
  /// while preparation is incomplete, and cancels it once everything's
  /// checked off. Re-synced every time this dashboard loads/refreshes
  /// rather than on a background schedule, since there's no server-side
  /// trigger to drive it otherwise.
  Future<void> _syncChecklistReminder(double progress) async {
    if (progress >= 1) {
      await NotificationService.instance.cancel(NotificationService.idChecklistReminder);
      return;
    }
    await NotificationService.instance.scheduleDailyReminder(
      id: NotificationService.idChecklistReminder,
      title: 'Emergency checklist incomplete',
      body: "You still have unchecked items on your emergency checklist — tap to review.",
    );
  }

  Future<void> _openAndRefresh(String routeName) async {
    await Navigator.of(context).pushNamed(routeName);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(title: const Text('Preparedness Planner')),
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
            ),
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: EdgeInsets.all(context.responsive(mobile: 16, tablet: 24, desktop: 32)),
                children: [
                  FutureBuilder<double>(
                    future: _progressFuture,
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Preparation progress',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: snapshot.connectionState == ConnectionState.waiting ? null : progress,
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(
                                  progress >= 1
                                      ? Colors.green
                                      : progress >= 0.5
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% of checklist items checked off',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _PlannerCard(
                    icon: Icons.checklist_outlined,
                    color: Colors.blue,
                    title: 'Emergency Checklist',
                    subtitle: 'Track what you\'ve packed and prepared',
                    onTap: () => _openAndRefresh(AppRoutes.checklist),
                  ),
                  const SizedBox(height: 12),
                  _PlannerCard(
                    icon: Icons.inventory_2_outlined,
                    color: Colors.teal,
                    title: 'Inventory',
                    subtitle: 'Emergency supplies on hand, by category',
                    onTap: () => _openAndRefresh(AppRoutes.inventory),
                  ),
                  const SizedBox(height: 12),
                  _PlannerCard(
                    icon: Icons.contact_phone_outlined,
                    color: Colors.purple,
                    title: 'Emergency Contacts',
                    subtitle: 'Family, neighbors, and emergency services',
                    onTap: () => _openAndRefresh(AppRoutes.contacts),
                  ),
                  const SizedBox(height: 12),
                  _PlannerCard(
                    icon: Icons.night_shelter_outlined,
                    color: Colors.green,
                    title: 'Nearby Evacuation Centers',
                    subtitle: 'Find and navigate to the nearest PPS',
                    onTap: () => _openAndRefresh(AppRoutes.ppsMap),
                  ),
                ],
              ),
            ),
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerCard extends StatelessWidget {
  const _PlannerCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
