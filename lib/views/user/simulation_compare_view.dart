import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/flood_simulation.dart';
import '../../models/simulation_factor.dart';
import '../../controllers/risk_assessment_controller.dart';
import '../../controllers/historical_flood_controller.dart';
import '../../controllers/environment_controller.dart';
import '../../services/historical_flood_service.dart';
import '../../services/terrain_service.dart';
import '../../services/weather_service.dart';
import '../../services/risk_assessment_service.dart';
import '../../services/flood_simulation_service.dart';
import '../../utils/responsive.dart';

/// Lets a user pick 2+ of their saved assessments and see risk scores and
/// contributing factors side by side (CLAUDE.md Task 5 — "compare multiple
/// simulations").
class SimulationCompareView extends StatefulWidget {
  const SimulationCompareView({super.key});

  @override
  State<SimulationCompareView> createState() => _SimulationCompareViewState();
}

class _SimulationCompareViewState extends State<SimulationCompareView> {
  final _riskAssessmentController = RiskAssessmentController(
    HistoricalFloodController(HistoricalFloodService()),
    EnvironmentController(TerrainService(), WeatherService()),
    RiskAssessmentService(),
    FloodSimulationService(),
  );

  late Future<List<FloodSimulation>> _simulationsFuture;
  final Set<String> _selectedIds = {};
  final Map<String, List<SimulationFactor>> _factorsById = {};
  bool _isLoadingFactors = false;

  @override
  void initState() {
    super.initState();
    _simulationsFuture = _riskAssessmentController.listSimulations();
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

  Future<void> _toggle(FloodSimulation sim, bool selected) async {
    final id = sim.id;
    if (id == null) return;
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
    if (selected && !_factorsById.containsKey(id)) {
      setState(() => _isLoadingFactors = true);
      final factors = await _riskAssessmentController.getFactors(id);
      if (!mounted) return;
      setState(() {
        _factorsById[id] = factors;
        _isLoadingFactors = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(title: const Text('Compare Assessments')),
      body: SafeArea(
        child: FutureBuilder<List<FloodSimulation>>(
          future: _simulationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final simulations = snapshot.data ?? [];
            if (simulations.length < 2) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Run at least 2 assessments to compare them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            final selected = simulations.where((s) => _selectedIds.contains(s.id)).toList();

            return SingleChildScrollView(
              padding: EdgeInsets.all(context.responsive(mobile: 16, tablet: 24, desktop: 32)),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select assessments to compare',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      ...simulations.map(
                        (sim) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selectedIds.contains(sim.id),
                          onChanged: (value) => _toggle(sim, value ?? false),
                          title: Text(sim.propertyName),
                          subtitle: Text(
                            '${sim.district}, ${sim.state} — ${sim.riskLevel} (${sim.riskScore.toStringAsFixed(0)})',
                          ),
                        ),
                      ),
                      if (selected.length >= 2) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Risk score comparison',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: BarChart(
                            BarChartData(
                              maxY: 100,
                              barGroups: [
                                for (var i = 0; i < selected.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: selected[i].riskScore,
                                        color: _levelColor(selected[i].riskLevel),
                                        width: 28,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ],
                                  ),
                              ],
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 36,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= selected.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          selected[i].propertyName,
                                          style: const TextStyle(fontSize: 10),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: const FlGridData(show: true, drawVerticalLine: false),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Contributing factors',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingFactors)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          ...selected.map(
                            (sim) => _SimulationFactorsCard(
                              simulation: sim,
                              factors: _factorsById[sim.id] ?? const [],
                              color: _levelColor(sim.riskLevel),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SimulationFactorsCard extends StatelessWidget {
  const _SimulationFactorsCard({
    required this.simulation,
    required this.factors,
    required this.color,
  });

  final FloodSimulation simulation;
  final List<SimulationFactor> factors;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  simulation.propertyName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${simulation.riskScore.toStringAsFixed(0)} · ${simulation.riskLevel}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in factors)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(child: Text(f.factorName, style: const TextStyle(fontSize: 12))),
                  Text(
                    '${f.scoreContribution >= 0 ? '+' : ''}${f.scoreContribution.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
