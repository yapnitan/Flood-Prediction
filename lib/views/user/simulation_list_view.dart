import 'package:flutter/material.dart';
import '../../models/flood_simulation.dart';
import '../../controllers/risk_assessment_controller.dart';
import '../../controllers/historical_flood_controller.dart';
import '../../controllers/environment_controller.dart';
import '../../services/historical_flood_service.dart';
import '../../services/terrain_service.dart';
import '../../services/weather_service.dart';
import '../../services/risk_assessment_service.dart';
import '../../services/flood_simulation_service.dart';
import '../../services/connectivity_service.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_arguments.dart';
import '../../utils/responsive.dart';

class SimulationListView extends StatefulWidget {
  const SimulationListView({super.key});

  @override
  State<SimulationListView> createState() => _SimulationListViewState();
}

class _SimulationListViewState extends State<SimulationListView> {
  final _riskAssessmentController = RiskAssessmentController(
    HistoricalFloodController(HistoricalFloodService()),
    EnvironmentController(TerrainService(), WeatherService()),
    RiskAssessmentService(),
    FloodSimulationService(),
  );

  late Future<List<FloodSimulation>> _simulationsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _simulationsFuture = _loadSimulations();
    });
  }

  /// Loads the saved assessments, then re-scores each one against current
  /// data (recent community reports, weather, river forecast) so the list
  /// stays in sync with the real-time detail view. One refresh pass per
  /// simulation — heavier than a plain read, but assessments are few per
  /// account. Skipped entirely when offline (the pipeline needs live APIs).
  Future<List<FloodSimulation>> _loadSimulations() async {
    final simulations = await _riskAssessmentController.listSimulations();
    if (!ConnectivityService.instance.isOnline) return simulations;
    return Future.wait(
      simulations.map((simulation) async {
        final outcome =
            await _riskAssessmentController.refreshSimulation(simulation);
        return outcome.simulation ?? simulation;
      }),
    );
  }

  Future<void> _handlePullToRefresh() async {
    final simulations = await _loadSimulations();
    if (!mounted) return;
    setState(() => _simulationsFuture = Future.value(simulations));
  }

  Future<void> _delete(String id) async {
    await _riskAssessmentController.deleteSimulation(id);
    _refresh();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Flood Risk Assessments'),
        actions: [
          IconButton(
            tooltip: 'Compare assessments',
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.simulationCompare),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.createSimulation);
          _refresh();
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<FloodSimulation>>(
        future: _simulationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final simulations = snapshot.data ?? [];
          if (simulations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handlePullToRefresh,
              child: ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No assessments yet — tap + to run one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _handlePullToRefresh,
            child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
              ),
              child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: simulations.length,
            itemBuilder: (context, index) {
              final sim = simulations[index];
              final color = _levelColor(sim.riskLevel);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.simulationDetail,
                      arguments: SimulationDetailArgs(simulation: sim),
                    );
                    _refresh();
                  },
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      sim.riskScore.toStringAsFixed(0),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    sim.propertyName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${sim.district}, ${sim.state}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _delete(sim.id!),
                  ),
                ),
              );
            },
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
