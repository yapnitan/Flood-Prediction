import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'user_profile.dart';

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

/// Placeholder pending the helper-specific feature set (e.g. assigned
/// community reports to verify) — kept minimal so the role has a working
/// home screen now instead of the previous UnimplementedError crash.
class _HelperDashboardTab extends StatelessWidget {
  const _HelperDashboardTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(
            context.responsive(mobile: 20, tablet: 28, desktop: 32),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.volunteer_activism_outlined, size: 64, color: Colors.blue),
              SizedBox(height: 16),
              Text(
                'Helper tools are coming soon',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Verifying community flood reports and coordinating relief '
                'will show up here once that module is ready.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
