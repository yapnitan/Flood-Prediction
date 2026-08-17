import 'package:flutter/material.dart';
import '../../controllers/repair_request_controller.dart';
import '../../models/repair_request.dart';
import '../../services/repair_request_service.dart';
import '../../utils/maps_launcher.dart';
import '../../utils/responsive.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import '../shared/user_profile.dart';
import 'repair_request_helper_detail_view.dart';

class HelperHome extends StatefulWidget {
  const HelperHome({super.key});

  @override
  State<HelperHome> createState() => _HelperHomeState();
}

class _HelperHomeState extends State<HelperHome> {
  int currentIndex = 0;

  final List<String> titles = ["Dashboard", "Profile"];

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = const [
      _HelperDashboardTab(),
      ProfilePage(),
    ];

    final bool useRail = !context.isMobile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[currentIndex],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        centerTitle: true,
      ),
      body: useRail
          ? Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => setState(() => currentIndex = index),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: Colors.blue),
            selectedLabelTextStyle: const TextStyle(color: Colors.blue),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: Text("Dashboard"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person),
                label: Text("Profile"),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[currentIndex]),
        ],
      )
          : pages[currentIndex],
      bottomNavigationBar: useRail
          ? null
          : BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

/// Helper's assigned recovery/repair tasks — requests an admin has
/// assigned to this helper, with status updates (in_progress/completed).
class _HelperDashboardTab extends StatefulWidget {
  const _HelperDashboardTab();

  @override
  State<_HelperDashboardTab> createState() => _HelperDashboardTabState();
}

class _HelperDashboardTabState extends State<_HelperDashboardTab> {
  final _controller = RepairRequestController(RepairRequestService());
  late Future<List<RepairRequest>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _controller.getMyAssignedTasks();
  }

  Future<void> _refresh() async {
    // Block body, not `=> expr` — an arrow body would make the assignment's
    // *value* (a Future) the closure's return value, and setState() only
    // accepts callbacks returning void.
    setState(() {
      _tasksFuture = _controller.getMyAssignedTasks();
    });
    await _tasksFuture;
  }

  /// Assigned work is fetched newest-first; re-sort so the most urgent
  /// task is always what the helper sees at the top of their list, not
  /// just whatever landed on their queue most recently.
  List<RepairRequest> _sortedByUrgency(List<RepairRequest> tasks) {
    final sorted = [...tasks];
    sorted.sort(RepairRequest.comparePriority);
    return sorted;
  }

  Future<void> _updateStatus(String requestId, String status) async {
    await _controller.updateStatus(requestId, status);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
          ),
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<RepairRequest>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildEmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load your tasks',
                    subtitle: 'Pull down to try again.',
                  );
                }

                final tasks = _sortedByUrgency(snapshot.data ?? []);
                if (tasks.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'No tasks assigned yet',
                    subtitle: 'Requests an admin assigns to you will show up here.',
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.all(context.responsive(mobile: 16, tablet: 24, desktop: 24)),
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RepairRequestHelperDetailView(
                            request: tasks[index],
                            controller: _controller,
                          ),
                        ),
                      );
                      _refresh();
                    },
                    child: _TaskCard(request: tasks[index], onUpdateStatus: _updateStatus),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(context.responsive(mobile: 20, tablet: 28, desktop: 32)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 64, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.request, required this.onUpdateStatus});

  final RepairRequest request;
  final Future<void> Function(String requestId, String status) onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final status = request.status;
    final isUrgent = request.priority == 'urgent';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.withValues(alpha: 0.04) : null,
        border: Border.all(
          color: isUrgent ? Colors.red.shade200 : Colors.grey.shade300,
          width: isUrgent ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  request.assistanceType,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              PriorityBadge(priority: request.priority, dense: true),
              if (request.isCriticalMedical) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 3),
                      Text('Critical', style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.locationName,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => openDirections(
                  context,
                  latitude: request.latitude,
                  longitude: request.longitude,
                ),
                icon: const Icon(Icons.directions, size: 16),
                label: const Text('Directions'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (request.facilityId != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.home_work_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Shelter: ${request.facilityId }',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (request.contactNumber != null && request.contactNumber!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(request.contactNumber!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],
          if (request.damageDescription != null && request.damageDescription!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              request.damageDescription!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          if (status == 'assigned')
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(request.id!, 'in_progress'),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text('Start task', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              ),
            )
          else if (status == 'in_progress')
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(request.id!, 'completed'),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Mark completed', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            )
          else if (status == 'completed')
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green),
                  SizedBox(width: 6),
                  Text('Task completed', style: TextStyle(color: Colors.green, fontSize: 13)),
                ],
              ),
        ],
      ),
    );
  }
}