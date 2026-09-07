import 'package:flood_prediction/views/user/submit_report.dart';
import 'package:flutter/material.dart';
import 'package:flood_prediction/views/shared/user_profile.dart';
import 'package:flood_prediction/utils/responsive.dart';
import 'package:flood_prediction/widgets/home_flood_overview.dart';
import 'package:flood_prediction/routes/app_routes.dart';
import 'package:flood_prediction/services/realtime_alert_service.dart';
import 'package:flood_prediction/widgets/offline_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'my_asset_loss_reports_view.dart';

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

  @override
  void initState() {
    super.initState();
    // Task 12 "aid assignment updates" — notifies this resident when one
    // of their own asset loss reports changes status.
    final accountId = Supabase.instance.client.auth.currentUser?.id;
    if (accountId != null) {
      RealtimeAlertService.instance.watchOwnAssetLossReports(accountId);
    }
  }

  @override
  void dispose() {
    RealtimeAlertService.instance.stopAssetLossReportWatch();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (index == 1) {
      _showReportChooser();
      return;
    }
    setState(() => currentIndex = index);
  }

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
              title: const Text('Report a flood'),
              subtitle: const Text('Share live flood conditions in your area'),
              onTap: () {
                Navigator.pop(context);
                setState(() => currentIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.home_repair_service_outlined,
                color: Colors.orange,
              ),
              title: const Text('Report Asset Loss'),
              subtitle: const Text(
                'Report assets lost or damaged by a flood',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.assetLossCreate);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return RefreshIndicator(
      onRefresh: () async {
        await _homeOverviewKey.currentState?.refreshLocation();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  const OfflineBanner(),
                  const SizedBox(height: 12),
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
                      icon: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Am I Safe? Run a Flood Risk Assessment",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ---- My asset loss reports entry point ----
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyAssetLossReportsView(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text(
                        "My Asset Loss Reports",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // ---- Preparedness planner entry point ----
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.planner);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.checklist_outlined),
                      label: const Text(
                        "Preparedness Planner",
                        style: TextStyle(fontWeight: FontWeight.bold),
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

    return PopScope(
      // Only let the system/back gesture actually leave this screen when
      // already on the Home tab — otherwise it pops the whole UserHome
      // route (landing on whatever's beneath it in the nav stack) instead
      // of just returning to Home like a bottom-nav app should.
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => currentIndex = 0);
      },
      child: Scaffold(
      appBar: AppBar(title: Text(titles[currentIndex])),

      // Both orientations keep an identical body element tree —
      // LayoutBuilder > Row > Expanded(keyed) > IndexedStack — and only
      // add/remove the leading NavigationRail. Without this, crossing the
      // `useRail` width breakpoint on rotation swapped the whole body subtree,
      // remounting the IndexedStack and wiping each tab's state.
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              if (useRail) ...[
                // NavigationRail isn't internally scrollable, so on a short
                // (e.g. landscape) screen it can overflow vertically. Let it
                // scroll while still stretching to fill the available
                // height so the VerticalDivider spans the full body.
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        onDestinationSelected: _onNavTap,
                        labelType: NavigationRailLabelType.all,
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
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                key: const ValueKey('userTabBody'),
                child: IndexedStack(index: currentIndex, children: pages),
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: useRail
          ? null
          : BottomNavigationBar(
              currentIndex: currentIndex,

              onTap: _onNavTap,

              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
                BottomNavigationBarItem(icon: Icon(Icons.add), label: "Report"),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: "Profile",
                ),
              ],
            ),
      ),
    );
  }
}
