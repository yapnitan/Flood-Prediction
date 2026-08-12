import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../controllers/user_management_controller.dart';
import '../../services/user_management_service.dart';
import '../../controllers/repair_request_controller.dart';
import '../../services/repair_request_service.dart';
import '../../utils/responsive.dart';
import 'user_management_view.dart';
import 'repair_request_admin_view.dart';
import '../shared/user_profile.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int currentIndex = 0;

  final List<String> titles = ["Dashboard", "User Management", "Recovery", "Profile"];

  final _repairRequestController = RepairRequestController(RepairRequestService());
  int _pendingRepairCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    final requests = await _repairRequestController.getAdminOverview();
    if (!mounted) return;
    setState(() {
      _pendingRepairCount = requests.where((r) => r['status'] == 'pending').length;
    });
  }

  void _onNavTap(int index) {
    setState(() => currentIndex = index);
    // Refresh the badge count whenever the admin leaves the Recovery tab,
    // so it reflects any approve/reject actions taken while inside it.
    if (index != 2) {
      _loadPendingCount();
    }
  }

  Widget _navIcon(IconData icon) {
    if (_pendingRepairCount == 0) return Icon(icon);
    return Badge(
      label: Text('$_pendingRepairCount'),
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const _AdminDashboardTab(),
      const UserManagementView(),
      RepairRequestAdminView(onRequestsChanged: _loadPendingCount),
      const ProfilePage(),
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
            onDestinationSelected: _onNavTap,
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: Colors.blue),
            selectedLabelTextStyle: const TextStyle(color: Colors.blue),
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
                label: const Text("Recovery"),
              ),
              const NavigationRailDestination(
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
        onTap: _onNavTap,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),
          const BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: "Users"),
          BottomNavigationBarItem(icon: _navIcon(Icons.assignment_outlined), label: "Recovery"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
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
            child: FutureBuilder<List<Account>>(
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
          ),
        ),
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
