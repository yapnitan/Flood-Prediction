import 'package:flutter/material.dart';
import '../models/account.dart';
import '../controllers/user_management_controller.dart';
import '../services/evacuation_center_service.dart';
import '../services/user_management_service.dart';
import '../utils/responsive.dart';
import 'evacuation_center_management_view.dart';
import 'user_management_view.dart';
import 'user_profile.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int currentIndex = 0;

  final List<String> titles = ["Dashboard", "User Management", "Profile"];

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = const [
      _AdminDashboardTab(),
      UserManagementView(),
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
                      icon: Icon(Icons.people_outline),
                      label: Text("Users"),
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
                BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: "Users"),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
              ],
            ),
    );
  }
}

/// Quick at-a-glance counts of registered accounts by role.
class _AdminDashboardTab extends StatefulWidget {
  const _AdminDashboardTab();

  @override
  State<_AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<_AdminDashboardTab> {
  final _controller = UserManagementController(UserManagementService());
  late Future<List<Account>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _controller.listUsers();
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
              maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
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
                    final helpers = users.where((u) => u.role == 'helper').length;
                    final regular = users.where((u) => u.role == 'user').length;
                    final disabled = users.where((u) => !u.isActive).length;

                    return GridView.count(
                      crossAxisCount: context.responsive(mobile: 2, tablet: 3, desktop: 4),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        _StatCard(label: 'Total Accounts', value: total, color: Colors.blue),
                        _StatCard(label: 'Users', value: regular, color: Colors.green),
                        _StatCard(label: 'Helpers', value: helpers, color: Colors.teal),
                        _StatCard(label: 'Admins', value: admins, color: Colors.purple),
                        _StatCard(label: 'Disabled', value: disabled, color: Colors.red),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ---- Evacuation Center Demographics Section ----
                const _EvacuationDemographicSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal bar chart showing the number of evacuation centers per state,
/// plus a "Manage Evacuation Center" button.
class _EvacuationDemographicSection extends StatelessWidget {
  const _EvacuationDemographicSection();

  @override
  Widget build(BuildContext context) {
    final demographics = EvacuationCenterService.stateCenterCounts;
    final sorted = demographics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isNotEmpty ? sorted.first.value : 1;
    final totalCenters = sorted.fold<int>(0, (sum, e) => sum + e.value);

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
                child: const Icon(Icons.other_houses_outlined, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evacuation Centers by State',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$totalCenters centers across ${sorted.length} states',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 28),

          // Bar chart rows
          ...List.generate(sorted.length, (index) {
            final entry = sorted[index];
            final fraction = entry.value / maxValue;
            final color = barColors[index % barColors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: context.responsive(mobile: 100, tablet: 130, desktop: 140),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EvacuationCenterManagementView(),
                  ),
                );
              },
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

  const _StatCard({required this.label, required this.value, required this.color});

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
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
