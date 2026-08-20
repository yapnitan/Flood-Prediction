import 'package:flutter/material.dart';
import '../../controllers/facility_controller.dart';
import '../../controllers/repair_request_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/account.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';
import '../../services/repair_request_service.dart';
import '../../services/user_management_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/animated_tab.dart';
import 'facility_management_view.dart';
import 'flood_report_admin_view.dart';
import 'repair_request_admin_view.dart';
import 'user_management_view.dart';
import '../shared/user_profile.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int currentIndex = 0;

  final List<String> titles = [
    "Dashboard",
    "User Management",
    "Recovery",
    "Facilities",
    "Profile",
  ];

  final _repairRequestController = RepairRequestController(
    RepairRequestService(),
  );
  int _pendingRepairCount = 0;

  /// Which report type the "Report" tab (index 2) currently shows — chosen
  /// via [_showReportChooser]. Kept as tab state (rather than pushing a
  /// separate page) so the flood report list shares this same [Scaffold]'s
  /// app bar and bottom navigation bar, exactly like the Recovery view.
  bool _showFloodReports = false;

  String get _reportTitle => _showFloodReports ? 'Flood Reports' : 'Recovery';

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final requests = await _repairRequestController.getAdminOverview();
    if (!mounted) return;
    setState(() {
      _pendingRepairCount = requests
          .where((r) => r['status'] == 'pending')
          .length;
    });
  }

  void _onNavTap(int index) {
    if (index == 2) {
      _showReportChooser();
      return;
    }
    setState(() => currentIndex = index);
    _loadPendingCount();
  }

  /// "Report" doesn't navigate directly — same interaction pattern as
  /// the User view's "Submit Report" chooser — it opens a sheet to pick
  /// which report to view first.
  void _showReportChooser() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.water_drop_outlined,
                color: Colors.blue,
              ),
              title: const Text('View Flood Report'),
              subtitle: const Text('Community-submitted flood conditions'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showFloodReports = true;
                  currentIndex = 2;
                });
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.assignment_outlined,
                color: Colors.orange,
              ),
              title: const Text('View Recovery Report'),
              subtitle: const Text('Repair and aid requests from residents'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _showFloodReports = false;
                  currentIndex = 2;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon) {
    if (_pendingRepairCount == 0) return Icon(icon);
    return Badge(label: Text('$_pendingRepairCount'), child: Icon(icon));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _AdminDashboardTab(onManageEvacuationCenters: () => _onNavTap(3)),
      const UserManagementView(),
      _showFloodReports
          ? const FloodReportAdminView()
          : RepairRequestAdminView(onRequestsChanged: _loadPendingCount),
      const FacilityManagementView(),
      const ProfilePage(),
    ];

    final bool useRail = !context.isMobile;

    return Scaffold(
      appBar: AppBar(title: Text(currentIndex == 2 ? _reportTitle : titles[currentIndex])),
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: _onNavTap,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: Text("Dashboard"),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      label: Text("Users"),
                    ),
                    NavigationRailDestination(
                      icon: _navIcon(Icons.assignment_outlined),
                      label: const Text("Report"),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.home_work_outlined),
                      label: Text("Facilities"),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.person),
                      label: Text("Profile"),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: AnimatedTab(index: currentIndex, child: pages[currentIndex])),
              ],
            )
          : AnimatedTab(index: currentIndex, child: pages[currentIndex]),
      bottomNavigationBar: useRail
          ? null
          : BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: _onNavTap,
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  label: "Dashboard",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  label: "Users",
                ),
                BottomNavigationBarItem(
                  icon: _navIcon(Icons.assignment_outlined),
                  label: "Report",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_work_outlined),
                  label: "Facilities",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
            ),
    );
  }
}

/// Quick at-a-glance counts of registered accounts by role.
class _AdminDashboardTab extends StatefulWidget {
  const _AdminDashboardTab({required this.onManageEvacuationCenters});

  final VoidCallback onManageEvacuationCenters;

  @override
  State<_AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<_AdminDashboardTab> {
  final _controller = UserManagementController(UserManagementService());
  final _facilityController = FacilityController(FacilityService());
  late Future<List<Account>> _usersFuture;
  late Future<List<Facility>> _sheltersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _controller.listUsers();
    _sheltersFuture = _facilityController.getAllFacilities();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          context.responsive(mobile: 20, tablet: 28, desktop: 32),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(
                mobile: 700,
                tablet: 800,
                desktop: 900,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Stat Cards Section ----
                FutureBuilder<List<Account>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final users = snapshot.data ?? [];
                    final total = users.length;
                    final admins = users.where((u) => u.role == 'admin').length;
                    final helpers = users
                        .where((u) => u.role == 'helper')
                        .length;
                    final regular = users.where((u) => u.role == 'user').length;
                    final disabled = users.where((u) => !u.isActive).length;

                    return GridView.count(
                      crossAxisCount: context.responsive(
                        mobile: 2,
                        tablet: 3,
                        desktop: 4,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _StatCard(
                          label: 'Total Accounts',
                          value: total,
                          color: Colors.blue,
                        ),
                        _StatCard(
                          label: 'Users',
                          value: regular,
                          color: Colors.green,
                        ),
                        _StatCard(
                          label: 'Helpers',
                          value: helpers,
                          color: Colors.teal,
                        ),
                        _StatCard(
                          label: 'Admins',
                          value: admins,
                          color: Colors.purple,
                        ),
                        _StatCard(
                          label: 'Disabled',
                          value: disabled,
                          color: Colors.red,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ---- Evacuation Center Demographics Section ----
                _EvacuationDemographicSection(
                  sheltersFuture: _sheltersFuture,
                  onManageTap: widget.onManageEvacuationCenters,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal bar chart showing each evacuation center (shelter) with its
/// capacity, sourced live from the `facilities` table in Supabase, plus a
/// "Manage Evacuation Center" button.
class _EvacuationDemographicSection extends StatelessWidget {
  const _EvacuationDemographicSection({
    required this.sheltersFuture,
    required this.onManageTap,
  });

  final Future<List<Facility>> sheltersFuture;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Facility>>(
      future: sheltersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _EvacuationSectionCard(
            child: Text('Could not load evacuation centers.'),
          );
        }

        final shelters = (snapshot.data ?? [])
            .where((f) => f.facilityType == 'shelter')
            .toList();

        return _EvacuationDemographicChart(
          shelters: shelters,
          onManageTap: onManageTap,
        );
      },
    );
  }
}

class _EvacuationSectionCard extends StatelessWidget {
  const _EvacuationSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EvacuationDemographicChart extends StatelessWidget {
  const _EvacuationDemographicChart({
    required this.shelters,
    required this.onManageTap,
  });

  final List<Facility> shelters;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final countsByState = <String, int>{};
    for (final facility in shelters) {
      final state = facility.state ?? 'Unknown';
      countsByState[state] = (countsByState[state] ?? 0) + 1;
    }
    final sorted = countsByState.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isNotEmpty ? sorted.first.value : 1;
    final totalCenters = shelters.length;

    // A palette of distinct colours for each bar.
    const barColors = [
      Color(0xFF1565C0), // blue 800
      Color(0xFF00897B), // teal 600
      Color(0xFF43A047), // green 600
      Color(0xFF7B1FA2), // purple 700
      Color(0xFFE53935), // red 600
      Color(0xFFFB8C00), // orange 600
      Color(0xFF3949AB), // indigo 600
      Color(0xFF00ACC1), // cyan 600
      Color(0xFF8E24AA), // purple 600
      Color(0xFF5E35B1), // deep-purple 600
      Color(0xFFD81B60), // pink 600
      Color(0xFF039BE5), // light-blue 600
      Color(0xFFC0CA33), // lime 600
      Color(0xFF6D4C41), // brown 600
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.other_houses_outlined,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evacuation Centers by State',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      totalCenters == 0
                          ? 'No evacuation centers yet'
                          : '$totalCenters centers across ${sorted.length} states',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 28),

          // Bar chart rows — one per state, bar length proportional to how
          // many evacuation centers are in that state.
          ...List.generate(sorted.length, (index) {
            final entry = sorted[index];
            final fraction = entry.value / maxValue;
            final color = barColors[index % barColors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: context.responsive(
                      mobile: 100,
                      tablet: 130,
                      desktop: 140,
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              height: 22,
                              width: constraints.maxWidth * fraction,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.7)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 20),

          // Manage Evacuation Center button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onManageTap,
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              label: const Text(
                'Manage Evacuation Centers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
