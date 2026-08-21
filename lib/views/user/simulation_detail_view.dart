import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/flood_simulation.dart';
import '../../models/historical_flood.dart';
import '../../models/simulation_factor.dart';
import '../../controllers/historical_flood_controller.dart';
import '../../services/flood_simulation_service.dart';
import '../../services/historical_flood_service.dart';
import '../../services/risk_assessment_service.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_arguments.dart';
import '../../utils/responsive.dart';

class SimulationDetailView extends StatefulWidget {
  final FloodSimulation simulation;

  /// Pre-computed factors/recommendations, available right after running a
  /// new assessment. When opened from the list instead, these are null and
  /// get fetched from Supabase in [initState].
  final List<SimulationFactor>? factors;
  final List<String>? recommendations;

  const SimulationDetailView({
    super.key,
    required this.simulation,
    this.factors,
    this.recommendations,
  });

  @override
  State<SimulationDetailView> createState() => _SimulationDetailViewState();
}

class _SimulationDetailViewState extends State<SimulationDetailView> {
  final _floodSimulationService = FloodSimulationService();
  final _historicalFloodController = HistoricalFloodController(HistoricalFloodService());
  final _riskAssessmentService = RiskAssessmentService();

  List<SimulationFactor> _factors = [];
  List<HistoricalFlood> _nearbyFloods = [];
  Map<int, int> _floodsPerYear = {};
  bool _isLoading = true;

  /// "Simulate preventive improvements" — starts from the simulation's
  /// actual saved protections, but toggling here only recomputes a local
  /// preview score (via [RiskAssessmentService], no network calls, nothing
  /// saved) so the user can see the what-if effect immediately.
  late bool _previewBarriers = widget.simulation.hasFloodBarriers;
  late bool _previewFoundation = widget.simulation.hasRaisedFoundation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sim = widget.simulation;

    final factorsFuture = widget.factors != null
        ? Future.value(widget.factors!)
        : (sim.id != null
            ? _floodSimulationService.getFactors(sim.id!)
            : Future.value(<SimulationFactor>[]));

    final nearbyFuture = _historicalFloodController.getNearby(
      latitude: sim.latitude,
      longitude: sim.longitude,
      radiusKm: 20,
    );

    final districtFuture = _historicalFloodController.search(
      state: sim.state,
      district: sim.district,
      pageSize: 200,
    );

    final results = await Future.wait([factorsFuture, nearbyFuture, districtFuture]);
    if (!mounted) return;

    final districtFloods = results[2] as List<HistoricalFlood>;
    final perYear = <int, int>{};
    for (final flood in districtFloods) {
      final year = flood.floodDate.year;
      perYear[year] = (perYear[year] ?? 0) + 1;
    }

    setState(() {
      _factors = results[0] as List<SimulationFactor>;
      _nearbyFloods = results[1] as List<HistoricalFlood>;
      _floodsPerYear = perYear;
      _isLoading = false;
    });
  }

  /// Recomputed purely client-side from the toggle state — the property's
  /// elevation/history/structure stay fixed at what was saved, only the
  /// mitigation flags vary, so this is a real "what if I added barriers"
  /// preview, not a re-run of the full assessment pipeline.
  RiskAssessmentResult get _previewResult {
    final sim = widget.simulation;
    return _riskAssessmentService.assess(
      RiskAssessmentInput(
        nearbyFloodCount: sim.nearbyFloodCount,
        propertyElevationMeters: sim.userElevationMeters ?? sim.terrainElevationMeters,
        baselineElevationMeters: sim.baselineElevationMeters,
        structureType: sim.structureType,
        hasFloodBarriers: _previewBarriers,
        hasRaisedFoundation: _previewFoundation,
      ),
    );
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
    final sim = widget.simulation;
    final levelColor = _levelColor(sim.riskLevel);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(sim.propertyName),
        actions: [
          IconButton(
            tooltip: 'Edit assessment',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.createSimulation,
              arguments: CreateSimulationArgs(existing: sim),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  context.responsive(mobile: 20, tablet: 32, desktop: 40),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.responsive(mobile: 700, tablet: 800),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ScoreCard(
                          score: sim.riskScore,
                          level: sim.riskLevel,
                          color: levelColor,
                        ),
                        const SizedBox(height: 16),

                        _SectionCard(
                          title: 'Property',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${sim.district}, ${sim.state}'),
                              const SizedBox(height: 4),
                              Text(
                                '${sim.latitude.toStringAsFixed(5)}, ${sim.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(sim.structureType),
                            ],
                          ),
                        ),

                        if (sim.currentWeatherSummary != null) ...[
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Current conditions (informational only)',
                            child: Text(sim.currentWeatherSummary!),
                          ),
                        ],

                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Contributing factors',
                          child: Column(
                            children: _factors
                                .map((f) => _FactorRow(factor: f))
                                .toList(),
                          ),
                        ),

                        const SizedBox(height: 12),
                        _PreventiveImprovementsCard(
                          hasFloodBarriers: _previewBarriers,
                          hasRaisedFoundation: _previewFoundation,
                          onBarriersChanged: (value) => setState(() => _previewBarriers = value),
                          onFoundationChanged: (value) => setState(() => _previewFoundation = value),
                          preview: _previewResult,
                          currentScore: sim.riskScore,
                        ),

                        if (_nearbyFloods.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Nearby historical flood events (20km)',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _nearbyFloods
                                  .take(10)
                                  .map((f) => _NearbyFloodRow(flood: f))
                                  .toList(),
                            ),
                          ),
                        ],

                        if (_floodsPerYear.length >= 2) ...[
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: '${sim.district} historical flood trend',
                            child: SizedBox(
                              height: 160,
                              child: _FloodTrendChart(floodsPerYear: _floodsPerYear),
                            ),
                          ),
                        ],

                        if (widget.recommendations != null &&
                            widget.recommendations!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Risk reduction recommendations',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: widget.recommendations!
                                  .map(
                                    (r) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(r)),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final double score;
  final String level;
  final Color color;

  const _ScoreCard({
    required this.score,
    required this.level,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$level Risk',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PreventiveImprovementsCard extends StatelessWidget {
  const _PreventiveImprovementsCard({
    required this.hasFloodBarriers,
    required this.hasRaisedFoundation,
    required this.onBarriersChanged,
    required this.onFoundationChanged,
    required this.preview,
    required this.currentScore,
  });

  final bool hasFloodBarriers;
  final bool hasRaisedFoundation;
  final ValueChanged<bool> onBarriersChanged;
  final ValueChanged<bool> onFoundationChanged;
  final RiskAssessmentResult preview;
  final double currentScore;

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
    final delta = preview.score - currentScore;
    final color = _levelColor(preview.level);

    return _SectionCard(
      title: 'Simulate preventive improvements',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Toggle protections to preview their effect on the risk score — '
            'nothing is saved until you edit the assessment.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Flood barriers'),
            value: hasFloodBarriers,
            onChanged: onBarriersChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Raised foundation'),
            value: hasRaisedFoundation,
            onChanged: onFoundationChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                preview.score.toStringAsFixed(0),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${preview.level} Risk',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (delta != 0)
                Flexible(
                  child: Text(
                    '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)} vs saved',
                    style: TextStyle(
                      color: delta > 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyFloodRow extends StatelessWidget {
  const _NearbyFloodRow({required this.flood});

  final HistoricalFlood flood;

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.water_damage_outlined, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flood.floodCause,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${flood.district}, ${flood.state} · ${_formatDate(flood.floodDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloodTrendChart extends StatelessWidget {
  const _FloodTrendChart({required this.floodsPerYear});

  final Map<int, int> floodsPerYear;

  @override
  Widget build(BuildContext context) {
    final years = floodsPerYear.keys.toList()..sort();
    final maxCount = floodsPerYear.values.fold<int>(0, (m, v) => v > m ? v : m);

    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        barGroups: [
          for (var i = 0; i < years.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (floodsPerYear[years[i]] ?? 0).toDouble(),
                  color: Colors.blue,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= years.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${years[i]}', style: const TextStyle(fontSize: 10)),
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
    );
  }
}

class _FactorRow extends StatelessWidget {
  final SimulationFactor factor;

  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final isMitigation = factor.scoreContribution < 0;
    final color = isMitigation
        ? Colors.green
        : (factor.scoreContribution > 0 ? Colors.red : Colors.grey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.factorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  factor.factorValue,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '${factor.scoreContribution >= 0 ? '+' : ''}${factor.scoreContribution.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
