import 'package:flood_prediction/views/user/submit_report.dart';
import 'package:flutter/material.dart';
import 'package:flood_prediction/views/shared/user_profile.dart';
import 'package:flood_prediction/utils/responsive.dart';
import 'package:flood_prediction/widgets/home_flood_map.dart';
import 'package:flood_prediction/routes/app_routes.dart';
import 'package:flood_prediction/controllers/area_risk_controller.dart';
import 'package:flood_prediction/controllers/environment_controller.dart';
import 'package:flood_prediction/controllers/flood_report_controller.dart';
import 'package:flood_prediction/controllers/historical_flood_controller.dart';
import 'package:flood_prediction/services/area_risk_service.dart';
import 'package:flood_prediction/services/flood_report_service.dart';
import 'package:flood_prediction/services/historical_flood_service.dart';
import 'package:flood_prediction/services/location_service.dart';
import 'package:flood_prediction/services/terrain_service.dart';
import 'package:flood_prediction/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int currentIndex = 0;
  final GlobalKey _reportPageKey = GlobalKey();
  final GlobalKey<HomeFloodMapState> _homeMapKey = GlobalKey<HomeFloodMapState>();

  final _locationService = LocationService();

  // Fetched once and shared with [HomeFloodMap] — two independent
  // `getCurrentPosition()` calls fired at once on Home-tab load can cause
  // one to time out on a real device (see [[Home Tab Flood Status Badge]]).
  late final Future<Position?> _positionFuture =
      _locationService.getCurrentPosition();

  final _areaRiskController = AreaRiskController(
    HistoricalFloodController(HistoricalFloodService()),
    EnvironmentController(TerrainService(), WeatherService()),
    FloodReportController(FloodReportService()),
    AreaRiskService(),
  );

  AreaRiskResult? _areaRisk;
  bool _isLoadingAreaRisk = true;

  // Titles corresponding to each tab, in the same order as `pages`
  final List<String> titles = ["Flood Watch", "Submit Report", "Profile"];

  @override
  void initState() {
    super.initState();
    _loadAreaRisk();
  }

  /// Combined "flood status" badge for wherever the user currently is —
  /// see [AreaRiskController.assessCurrentLocation] for how the historical
  /// baseline, live rainfall, and nearby community reports are combined.
  Future<void> _loadAreaRisk() async {
    if (!_isLoadingAreaRisk) setState(() => _isLoadingAreaRisk = true);
    final position = await _positionFuture;
    if (!mounted) return;
    if (position == null) {
      setState(() => _isLoadingAreaRisk = false);
      return;
    }
    final result = await _areaRiskController.assessCurrentLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (!mounted) return;
    setState(() {
      _areaRisk = result;
      _isLoadingAreaRisk = false;
    });
  }

  IconData _areaRiskIcon(String? level) {
    switch (level) {
      case 'High':
        return Icons.dangerous;
      case 'Medium':
        return Icons.warning_amber_rounded;
      case 'Low':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Color _areaRiskColor(String? level) {
    switch (level) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showAreaRiskDetail(AreaRiskResult risk) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _areaRiskIcon(risk.level),
                  color: _areaRiskColor(risk.level),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${risk.level} flood risk right now',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${risk.score.toStringAsFixed(0)}/100',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final factor in risk.factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            factor.factorName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            factor.factorValue,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${factor.scoreContribution.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'This combines nearby historical flood records with live rainfall '
              'and recent community reports near your current location — it\'s '
              'a general area indicator, not a substitute for running a full '
              'property risk assessment.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

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

                // ---- Flood status + alert icon ----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoBox(
                        child: InkWell(
                          onTap: _areaRisk == null
                              ? null
                              : () => _showAreaRiskDetail(_areaRisk!),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Flood status",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (_isLoadingAreaRisk)
                                const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Text(
                                  _areaRisk != null
                                      ? '${_areaRisk!.level} risk'
                                      : 'Unavailable',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _areaRiskColor(_areaRisk?.level),
                                  ),
                                ),
                              if (_areaRisk != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Tap for details',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoBox(
                        child: Center(
                          child: _isLoadingAreaRisk
                              ? const CircularProgressIndicator()
                              : Icon(
                                  _areaRiskIcon(_areaRisk?.level),
                                  size: 48,
                                  color: _areaRiskColor(_areaRisk?.level),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ---- Current location + nearby flood reports ----
                const Text(
                  "Current location",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                HomeFloodMap(key: _homeMapKey, positionFuture: _positionFuture),

                const SizedBox(height: 20),

                // ---- Rainfall / Water level / Risk level ----
                Row(
                  children: [
                    Expanded(
                      child: _InfoBox(
                        child: Column(
                          children: [
                            Text(
                              "Rainfall",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text("xxxx"),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _InfoBox(
                        child: Column(
                          children: [
                            Text(
                              "Water level",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text("xxxx"),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _InfoBox(
                        child: Column(
                          children: [
                            Text(
                              "Risk level",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text("xxxx"),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
          _homeMapKey.currentState?.refresh();
          _loadAreaRisk();
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

// _InfoBox must live OUTSIDE _UserHomeState, as its own top-level class.
class _InfoBox extends StatelessWidget {
  final Widget child;

  const _InfoBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
