import 'package:flutter/material.dart';

import '../../constants/resource_cost_rates.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../controllers/facility_controller.dart';
import '../../controllers/shelter_occupancy_controller.dart';
import '../../models/facility.dart';
import '../../models/shelter_occupancy_report.dart';
import '../../services/asset_loss_report_service.dart';
import '../../services/facility_service.dart';
import '../../services/shelter_occupancy_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/responsive.dart';

/// Admin's Economic Loss Dashboard (Task/asset report §11-§17): combines
/// counted asset loss (helper-verified + admin-approved) with Resource
/// Consumption Cost, and distinguishes reported-potential, helper-verified
/// and admin-approved figures throughout — never lets a still-pending
/// report silently inflate the official total.
class EconomicLossDashboardView extends StatefulWidget {
  const EconomicLossDashboardView({super.key});

  @override
  State<EconomicLossDashboardView> createState() => _EconomicLossDashboardViewState();
}

class _EconomicLossDashboardViewState extends State<EconomicLossDashboardView> {
  final _assetLossController = AssetLossReportController(AssetLossReportService());
  final _shelterController = ShelterOccupancyController(ShelterOccupancyService());
  final _facilityController = FacilityController(FacilityService());

  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  /// Shelter occupancy daily log, one entry per (shelter, date), newest date
  /// first. The resource-cost total is the sum of every entry; the breakdown
  /// card lets the admin filter it by month / date.
  List<ShelterOccupancyReport> _dailyLog = [];
  Map<String, Facility> _facilitiesById = {};

  String _monthFilter = 'all'; // 'YYYY-MM'
  String _dayFilter = 'all'; // 'YYYY-MM-DD'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await _assetLossController.getAdminOverview();
    final dailyLog = await _shelterController.getDailyLog();
    final facilities = await _facilityController.getAllFacilities();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _dailyLog = dailyLog;
      _facilitiesById = {
        for (final f in facilities)
          if (f.id != null) f.id!: f,
      };
      _isLoading = false;
    });
  }

  String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  List<ShelterOccupancyReport> get _filteredLog => _dailyLog.where((r) {
        if (_monthFilter != 'all' && _monthKey(r.occupancyDate) != _monthFilter) {
          return false;
        }
        if (_dayFilter != 'all' && r.dateKey != _dayFilter) return false;
        return true;
      }).toList();

  double _sum(Iterable<Map<String, dynamic>> rows, String field) =>
      rows.fold(0.0, (sum, r) => sum + ((r[field] as num?)?.toDouble() ?? 0));

  /// What one report contributes to the official total: an admin-approved
  /// report counts its approved figure; a helper-verified report (still
  /// awaiting admin approval) counts its verified figure; anything else
  /// contributes nothing.
  static double _contribution(Map<String, dynamic> r) {
    switch (r['status']) {
      case 'verified':
        return (r['approved_total_loss'] as num?)?.toDouble() ?? 0;
      case 'helper_verified':
        return (r['verified_total_loss'] as num?)?.toDouble() ?? 0;
      default:
        return 0;
    }
  }

  String _monthLabel(String key) {
    if (key == 'all') return 'All months';
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final parts = key.split('-');
    return '${names[int.parse(parts[1]) - 1]} ${parts[0]}';
  }

  String _dayLabel(String key) {
    if (key == 'all') return 'All dates';
    final p = key.split('-');
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  Widget _buildResourceCostCard(double allTimeTotal) {
    final months = _dailyLog
        .map((r) => _monthKey(r.occupancyDate))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final days = _monthFilter == 'all'
        ? <String>[]
        : (_dailyLog
            .where((r) => _monthKey(r.occupancyDate) == _monthFilter)
            .map((r) => r.dateKey)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a)));

    final filtered = _filteredLog;
    final byDate = <String, List<ShelterOccupancyReport>>{};
    for (final r in filtered) {
      byDate.putIfAbsent(r.dateKey, () => []).add(r);
    }
    final orderedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final filteredTotal = filtered.fold<double>(0, (s, r) => s + r.cost);
    final filtering = _monthFilter != 'all' || _dayFilter != 'all';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resource Consumption Cost by Date',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: months.contains(_monthFilter) ? _monthFilter : 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Month', isDense: true, border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All months')),
                    for (final m in months)
                      DropdownMenuItem(value: m, child: Text(_monthLabel(m))),
                  ],
                  onChanged: (v) => setState(() {
                    _monthFilter = v ?? 'all';
                    _dayFilter = 'all';
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: days.contains(_dayFilter) ? _dayFilter : 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Date', isDense: true, border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All dates')),
                    for (final d in days)
                      DropdownMenuItem(value: d, child: Text(_dayLabel(d))),
                  ],
                  onChanged: _monthFilter == 'all'
                      ? null
                      : (v) => setState(() => _dayFilter = v ?? 'all'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orderedDates.isEmpty)
            Text(
              _dailyLog.isEmpty
                  ? 'No shelter occupancy logged yet.'
                  : 'No occupancy in the selected period.',
              style: const TextStyle(color: Colors.grey),
            )
          else
            for (final date in orderedDates)
              _DateCostTile(
                key: ValueKey(date),
                date: date,
                label: _dayLabel(date),
                reports: byDate[date]!,
                facilitiesById: _facilitiesById,
              ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                filtering ? 'Selected period' : 'All-time total',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                formatRinggit(filtering ? filteredTotal : allTimeTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal,
                ),
              ),
            ],
          ),
          if (filtering) ...[
            const SizedBox(height: 2),
            Text(
              'All-time total: ${formatRinggit(allTimeTotal)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Priced per person per day: adult ${formatRinggit(ResourceCostRates.perAdult)}, '
            'child ${formatRinggit(ResourceCostRates.perChild)}, '
            'elderly ${formatRinggit(ResourceCostRates.perElderly)}, '
            'infant ${formatRinggit(ResourceCostRates.perInfant)}, '
            'person with disability ${formatRinggit(ResourceCostRates.perPersonWithDisability)}.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Reports that count toward the official total right now: admin-approved
    // plus helper-verified (the latter drop out again if the admin rejects).
    final countedReports = _reports
        .where((r) =>
            r['status'] == 'verified' || r['status'] == 'helper_verified')
        .toList();
    final pendingReports = _reports.where((r) => r['status'] == 'pending_review').toList();

    final adminApprovedLoss = _sum(
      _reports.where((r) => r['status'] == 'verified'),
      'approved_total_loss',
    );
    final helperVerifiedLoss = _sum(
      _reports.where((r) => r['status'] == 'helper_verified'),
      'verified_total_loss',
    );
    final countedAssetLoss = adminApprovedLoss + helperVerifiedLoss;
    final potentialPending = _sum(pendingReports, 'estimated_total_loss');
    final resourceCostTotal =
        _dailyLog.fold<double>(0, (sum, r) => sum + r.cost);
    final totalEconomicLoss = countedAssetLoss + resourceCostTotal;

    final byState = <String, double>{};
    final byDistrict = <String, double>{};
    final byCategory = <String, double>{};
    final byIncident = <String, double>{};

    for (final r in countedReports) {
      final amount = _contribution(r);
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
                  _TotalCard(total: totalEconomicLoss, assetLoss: countedAssetLoss, resourceCost: resourceCostTotal),
                  const SizedBox(height: 16),
                  _PotentialVsVerifiedCard(
                    potential: potentialPending,
                    helperVerified: helperVerifiedLoss,
                    adminApproved: adminApprovedLoss,
                  ),
                  const SizedBox(height: 16),
                  _BreakdownCard(title: 'Counted Asset Loss by State', amounts: byState),
                  const SizedBox(height: 16),
                  _BreakdownCard(title: 'Counted Asset Loss by District', amounts: byDistrict),
                  const SizedBox(height: 16),
                  _BreakdownCard(title: 'Counted Asset Loss by Asset Category', amounts: byCategory),
                  if (byIncident.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _BreakdownCard(title: 'Counted Asset Loss by Flood Incident', amounts: byIncident),
                  ],
                  const SizedBox(height: 16),
                  _buildResourceCostCard(resourceCostTotal),
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

  String _rm(double v) => formatRinggit(v);

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

/// §17: never conflates a pending report's amount with the counted total,
/// and shows how much of the counted total is still only helper-verified
/// (i.e. could still be removed if the admin rejects it).
class _PotentialVsVerifiedCard extends StatelessWidget {
  const _PotentialVsVerifiedCard({
    required this.potential,
    required this.helperVerified,
    required this.adminApproved,
  });

  final double potential;
  final double helperVerified;
  final double adminApproved;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reported vs Counted Asset Loss', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.hourglass_top, size: 18, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text('Pending potential loss: ${formatRinggit(potential)}')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Helper-verified, awaiting approval: ${formatRinggit(helperVerified)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text('Admin-approved loss: ${formatRinggit(adminApproved)}')),
            ],
          ),
        ],
      ),
    );
  }
}

/// One date in the resource-cost breakdown — the day's total across every
/// shelter in the title, expanding to the per-shelter figures.
class _DateCostTile extends StatelessWidget {
  const _DateCostTile({
    super.key,
    required this.date,
    required this.label,
    required this.reports,
    required this.facilitiesById,
  });

  final String date;
  final String label;
  final List<ShelterOccupancyReport> reports;
  final Map<String, Facility> facilitiesById;

  @override
  Widget build(BuildContext context) {
    final dayTotal = reports.fold<double>(0, (s, r) => s + r.cost);
    final sorted = [...reports]..sort((a, b) => b.cost.compareTo(a.cost));

    // `shape`/`collapsedShape` kill the ExpansionTile divider lines without a
    // Theme(dividerColor: transparent) wrapper — wrapping each tile in its
    // own Theme element can trip the framework's `_dependents.isEmpty`
    // assertion when the list rebuilds on a filter change mid-animation.
    return ExpansionTile(
      key: PageStorageKey(date),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
      title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              formatRinggit(dayTotal),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ],
        ),
        subtitle: Text(
          '${reports.length} ${reports.length == 1 ? 'shelter' : 'shelters'}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        children: [
          for (final r in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facilitiesById[r.facilityId]?.name ?? 'Unknown shelter',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${r.totalVictims ?? r.headcount} '
                          '${(r.totalVictims ?? r.headcount) == 1 ? 'person' : 'people'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatRinggit(r.cost),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
            ),
        ],
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
            const Text('No counted losses yet.', style: TextStyle(color: Colors.grey))
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
                        'RM ${groupThousands(entry.value.toStringAsFixed(0))}',
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
