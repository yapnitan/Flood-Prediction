import 'package:flutter/material.dart';
import '../../models/flood_simulation.dart';
import '../../models/simulation_factor.dart';
import '../../services/flood_simulation_service.dart';
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

  List<SimulationFactor> _factors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.factors != null) {
      setState(() {
        _factors = widget.factors!;
        _isLoading = false;
      });
      return;
    }

    final id = widget.simulation.id;
    final factors = id != null
        ? await _floodSimulationService.getFactors(id)
        : <SimulationFactor>[];

    if (!mounted) return;
    setState(() {
      _factors = factors;
      _isLoading = false;
    });
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
      appBar: AppBar(title: Text(sim.propertyName), centerTitle: true),
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
