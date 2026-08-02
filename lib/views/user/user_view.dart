import 'package:flood_prediction/views/user/submit_report.dart';
import 'package:flutter/material.dart';
import 'package:flood_prediction/views/shared/user_profile.dart';
import 'package:flood_prediction/utils/responsive.dart';
import 'package:flood_prediction/widgets/home_flood_overview.dart';
import 'package:flood_prediction/routes/app_routes.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int currentIndex = 0;
  final GlobalKey _reportPageKey = GlobalKey();
  final GlobalKey<HomeFloodOverviewState> _homeOverviewKey =
      GlobalKey<HomeFloodOverviewState>();

  // Titles corresponding to each tab, in the same order as `pages`
  final List<String> titles = ["Flood Watch", "Submit Report", "Profile"];

  Widget _buildHomePage() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.responsive(
              mobile: 700,
              tablet: 800,
              desktop: 900,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              context.responsive(mobile: 20, tablet: 28, desktop: 32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Flood risk simulator entry point ----
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.simulationList);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_outlined, color: Colors.white),
                    label: const Text(
                      "Am I Safe? Run a Flood Risk Assessment",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ---- Flood status + alert icon + current-location map +
                //      rainfall / water level / nearby report count ----
                HomeFloodOverview(key: _homeOverviewKey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      SubmitReportPage(
        key: _reportPageKey,
        onSubmissionComplete: () {
          setState(() => currentIndex = 0);
          _homeOverviewKey.currentState?.refresh();
        },
      ),
      const ProfilePage(),
    ];

    // On tablet/desktop widths a side NavigationRail makes better use of
    // the horizontal space than a bottom bar.
    final bool useRail = !context.isMobile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[currentIndex],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        centerTitle: true,
      ),

      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Colors.blue),
                  selectedLabelTextStyle: const TextStyle(color: Colors.blue),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home),
                      label: Text("Home"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.add),
                      label: Text("Report"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person),
                      label: Text("Profile"),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: currentIndex, children: pages),
                ),
              ],
            )
          : IndexedStack(index: currentIndex, children: pages),

      bottomNavigationBar: useRail
          ? null
          : BottomNavigationBar(
              currentIndex: currentIndex,

              onTap: (index) {
                setState(() {
                  currentIndex = index;
                });
              },

              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,

              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: "Home",
                ),
                BottomNavigationBarItem(icon: Icon(Icons.add), label: "Report"),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
            ),
    );
  }
}
