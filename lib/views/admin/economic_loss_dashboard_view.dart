import 'package:flutter/material.dart';

import '../../controllers/asset_loss_report_controller.dart';
import '../../controllers/shelter_occupancy_controller.dart';
import '../../services/asset_loss_report_service.dart';
import '../../services/shelter_occupancy_service.dart';
import '../../utils/responsive.dart';

/// Admin's Economic Loss Dashboard (Task/asset report §11-§17): combines
/// VERIFIED/APPROVED asset loss with Resource Consumption Cost, and
/// distinguishes reported-potential from verified figures throughout —
/// never lets a pending report silently inflate the official total.
class EconomicLossDashboardView extends StatefulWidget {
  const EconomicLossDashboardView({super.key});

  @override
  State<EconomicLossDashboardView> createState() => _EconomicLossDashboardViewState();
}

class _EconomicLossDashboardViewState extends State<EconomicLossDashboardView> {
  final _assetLossController = AssetLossReportController(AssetLossReportService());
  final _shelterController = ShelterOccupancyController(ShelterOccupancyService());

  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  double _resourceCost = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await _assetLossController.getAdminOverview();
    final latestByFacility = await _shelterController.getLatestPerFacility();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _resourceCost = latestByFacility.values.fold(0.0, (sum, r) => sum + (r.resourceCost ?? r.calculatedResourceCost));
      _isLoading = false;
    });
  }

  double _sum(Iterable<Map<String, dynamic>> rows, String field) =>
      rows.fold(0.0, (sum, r) => sum + ((r[field] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final verifiedReports = _reports.where((r) => r['status'] == 'verified').toList();
    final pendingReports = _reports.where((r) => r['status'] == 'pending_review').toList();

    final approvedAssetLoss = _sum(verifiedReports, 'approved_total_loss');
    final potentialPending = _sum(pendingReports, 'estimated_total_loss');
    final totalEconomicLoss = approvedAssetLoss + _resourceCost;

    final byState = <String, double>{};
    final byDistrict = <String, double>{};
    final byCategory = <String, double>{};
    final byIncident = <String, double>{};

    for (final r in verifiedReports) {
      final amount = (r['approved_total_loss'] as num?)?.toDouble() ?? 0;
      final property = r['property'] as Map<String, dynamic>?;
      final incident = r['flood_incident'] as Map<String, dynamic>?;
      final state = property?['state'] as String? ?? 'Unknown';
      final district = property?['district'] as String? ?? 'Unknown';
      final category = r['asset_category'] as String? ?? 'Other';
      byState[state] = (byState[state] ?? 0) + amount;
      byDistrict['$district, $state'] = (byDistrict['$district, $state'] ?? 0) + amount;
      byCategory[category] = (byCategory[category] ?? 0) + amount;
      if (incident != null) {
        final name = incident['name'] as String;
        byIncident[name] = (byIncident[name] ?? 0) + amount;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(title: const Text('Economic Loss Dashboard'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 900, desktop: 1000)),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _TotalCard(total: totalEconomicLoss, assetLoss: approvedAssetLoss, resourceCost: _resourceCost),
                  const SizedBox(height: 16),
                  _PotentialVsVerifiedCard(potential: potentialPending, verified: approvedAssetLoss),
                  const SizedBox(height: 16),
                  _BreakdownCard(title: 'Verified Asset Loss by State', amounts: byState),
                  const SizedBox(height: 16),
                  _BreakdownCard(title: 'Verified Asset Loss by District', amounts: byDistrict),
                  const SizedBox(height: 16),
                  _BreakdownCard(title: 'Verified Asset Loss by Asset Category', amounts: byCategory),
                  if (byIncident.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _BreakdownCard(title: 'Verified Asset Loss by Flood Incident', amounts: byIncident),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.assetLoss, required this.resourceCost});

  final double total;
  final double assetLoss;
  final double resourceCost;

  String _rm(double v) => 'RM ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Estimated Economic Loss', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 6),
          Text(_rm(total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(child: _StatColumn(label: 'Asset Loss', value: _rm(assetLoss), color: Colors.indigo)),
              Expanded(child: _StatColumn(label: 'Resource Cost', value: _rm(resourceCost), color: Colors.teal)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ],
    );
  }
}

/// §17: never conflates a pending report's amount with the verified total.
class _PotentialVsVerifiedCard extends StatelessWidget {
  const _PotentialVsVerifiedCard({required this.potential, required this.verified});

  final double potential;
  final double verified;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reported vs Verified Asset Loss', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.hourglass_top, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text('Pending potential loss: RM ${potential.toStringAsFixed(2)}')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('Verified/approved loss: RM ${verified.toStringAsFixed(2)}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.amounts});

  final String title;
  final Map<String, double> amounts;

  @override
  Widget build(BuildContext context) {
    final sorted = amounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isNotEmpty ? sorted.first.value : 1;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            const Text('No verified losses yet.', style: TextStyle(color: Colors.grey))
          else
            ...sorted.map((entry) {
              final fraction = maxValue == 0 ? 0.0 : entry.value / maxValue;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(entry.key, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            Container(
                              height: 18,
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                            ),
                            Container(
                              height: 18,
                              width: constraints.maxWidth * fraction,
                              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: Text(
                        'RM ${entry.value.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
