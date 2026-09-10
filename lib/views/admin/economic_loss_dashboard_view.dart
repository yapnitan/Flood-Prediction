import 'package:fl_chart/fl_chart.dart';
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

  List<ShelterOccupancyReport> _dailyLog = [];
  Map<String, Facility> _facilitiesById = {};

  String _monthFilter = 'all'; // 'YYYY-MM'
  String _dayFilter = 'all'; // 'YYYY-MM-DD'

  bool get _filtering => _monthFilter != 'all' || _dayFilter != 'all';

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

  String _dayKey(DateTime d) =>
      '${_monthKey(d)}-${d.day.toString().padLeft(2, '0')}';

  bool _inPeriod(DateTime? d) {
    if (d == null) return !_filtering; // undated rows only show unfiltered
    if (_monthFilter != 'all' && _monthKey(d) != _monthFilter) return false;
    if (_dayFilter != 'all' && _dayKey(d) != _dayFilter) return false;
    return true;
  }

  DateTime? _reportDate(Map<String, dynamic> r) {
    final raw = (r['created_at'] ?? r['reviewed_at']) as String?;
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  List<Map<String, dynamic>> get _filteredReports =>
      _reports.where((r) => _inPeriod(_reportDate(r))).toList();

  List<ShelterOccupancyReport> get _filteredLog =>
      _dailyLog.where((r) => _inPeriod(r.occupancyDate)).toList();

  List<String> get _availableMonths {
    final set = <String>{};
    for (final r in _reports) {
      final d = _reportDate(r);
      if (d != null) set.add(_monthKey(d));
    }
    for (final r in _dailyLog) {
      set.add(_monthKey(r.occupancyDate));
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  List<String> get _availableDays {
    if (_monthFilter == 'all') return const [];
    final set = <String>{};
    for (final r in _reports) {
      final d = _reportDate(r);
      if (d != null && _monthKey(d) == _monthFilter) set.add(_dayKey(d));
    }
    for (final r in _dailyLog) {
      if (_monthKey(r.occupancyDate) == _monthFilter) set.add(r.dateKey);
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  double _sum(Iterable<Map<String, dynamic>> rows, String field) =>
      rows.fold(0.0, (sum, r) => sum + ((r[field] as num?)?.toDouble() ?? 0));

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

  Widget _buildPeriodFilter() {
    final months = _availableMonths;
    final days = _availableDays;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Period',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (_filtering)
                TextButton(
                  onPressed: () => setState(() {
                    _monthFilter = 'all';
                    _dayFilter = 'all';
                  }),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  Widget _buildResourceCostCard(double allTimeTotal) {
    final filtered = _filteredLog;
    final byDate = <String, List<ShelterOccupancyReport>>{};
    for (final r in filtered) {
      byDate.putIfAbsent(r.dateKey, () => []).add(r);
    }
    final orderedDates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final filteredTotal = filtered.fold<double>(0, (s, r) => s + r.cost);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resource Consumption Cost by Date',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                _filtering ? 'Selected period' : 'All-time total',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                formatRinggit(_filtering ? filteredTotal : allTimeTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal,
                ),
              ),
            ],
          ),
          if (_filtering) ...[
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

    final reports = _filteredReports;
    final log = _filteredLog;


    final countedReports = reports
        .where((r) =>
            r['status'] == 'verified' || r['status'] == 'helper_verified')
        .toList();
    final pendingReports = reports.where((r) => r['status'] == 'pending_review').toList();

    final adminApprovedLoss = _sum(
      reports.where((r) => r['status'] == 'verified'),
      'approved_total_loss',
    );
    final helperVerifiedLoss = _sum(
      reports.where((r) => r['status'] == 'helper_verified'),
      'verified_total_loss',
    );
    final countedAssetLoss = adminApprovedLoss + helperVerifiedLoss;
    final potentialPending = _sum(pendingReports, 'estimated_total_loss');
    final resourceCostTotal = log.fold<double>(0, (sum, r) => sum + r.cost);
    final resourceCostAllTime =
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

    final resourceByDate = <String, double>{};
    final resourceByShelter = <String, double>{};
    for (final r in log) {
      final d = _dayLabel(r.dateKey);
      resourceByDate[d] = (resourceByDate[d] ?? 0) + r.cost;
      final name = _facilitiesById[r.facilityId]?.name ?? 'Unknown shelter';
      resourceByShelter[name] = (resourceByShelter[name] ?? 0) + r.cost;
    }

    final dimensions = <String, Map<String, double>>{
      'Asset loss by state': byState,
      'Asset loss by district': byDistrict,
      'Asset loss by category': byCategory,
      if (byIncident.isNotEmpty) 'Asset loss by flood incident': byIncident,
      'Resource cost by date': resourceByDate,
      'Resource cost by shelter': resourceByShelter,
    };

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
                  _buildPeriodFilter(),
                  const SizedBox(height: 16),
                  _TotalCard(
                    total: totalEconomicLoss,
                    assetLoss: countedAssetLoss,
                    resourceCost: resourceCostTotal,
                    periodLabel: _filtering
                        ? (_dayFilter != 'all'
                            ? _dayLabel(_dayFilter)
                            : _monthLabel(_monthFilter))
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _PotentialVsVerifiedCard(
                    potential: potentialPending,
                    helperVerified: helperVerifiedLoss,
                    adminApproved: adminApprovedLoss,
                  ),
                  const SizedBox(height: 16),
                  _BreakdownExplorerCard(dimensions: dimensions),
                  const SizedBox(height: 16),
                  _buildResourceCostCard(resourceCostAllTime),
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
  const _TotalCard({
    required this.total,
    required this.assetLoss,
    required this.resourceCost,
    this.periodLabel,
  });

  final double total;
  final double assetLoss;
  final double resourceCost;

  final String? periodLabel;

  String _rm(double v) => formatRinggit(v);

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            periodLabel == null
                ? 'Total Estimated Economic Loss'
                : 'Estimated Economic Loss · $periodLabel',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
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

enum _ChartKind { bar, pie }

class _BreakdownExplorerCard extends StatefulWidget {
  const _BreakdownExplorerCard({required this.dimensions});

  final Map<String, Map<String, double>> dimensions;

  @override
  State<_BreakdownExplorerCard> createState() => _BreakdownExplorerCardState();
}

class _BreakdownExplorerCardState extends State<_BreakdownExplorerCard> {
  late String _dimension = widget.dimensions.keys.first;
  _ChartKind _kind = _ChartKind.bar;

  static const _palette = <Color>[
    Color(0xFF4E79A7), Color(0xFFF28E2B), Color(0xFFE15759), Color(0xFF76B7B2),
    Color(0xFF59A14F), Color(0xFFEDC948), Color(0xFFB07AA1), Color(0xFFFF9DA7),
    Color(0xFF9C755F), Color(0xFFBAB0AC), Color(0xFF86BCB6), Color(0xFFD37295),
  ];

  /// Top 11 entries by value, with the remainder folded into "Other".
  List<MapEntry<String, double>> _rows(Map<String, double> amounts) {
    final sorted = amounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= 12) return sorted;
    final head = sorted.take(11).toList();
    final rest = sorted.skip(11).fold<double>(0, (s, e) => s + e.value);
    return [...head, MapEntry('Other (${sorted.length - 11})', rest)];
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.dimensions.containsKey(_dimension)) {
      _dimension = widget.dimensions.keys.first;
    }
    final rows = _rows(widget.dimensions[_dimension] ?? const {});
    final total = rows.fold<double>(0, (s, e) => s + e.value);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Economic Loss Breakdown',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              SegmentedButton<_ChartKind>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(value: _ChartKind.bar, icon: Icon(Icons.bar_chart)),
                  ButtonSegment(value: _ChartKind.pie, icon: Icon(Icons.pie_chart_outline)),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.dimensions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final key = widget.dimensions.keys.elementAt(i);
                return ChoiceChip(
                  label: Text(key),
                  selected: _dimension == key,
                  onSelected: (_) => setState(() => _dimension = key),
                  selectedColor: Colors.blue.shade100,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _dimension == key ? Colors.blue.shade900 : Colors.black87,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No data for this breakdown yet.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            SizedBox(
              height: 220,
              child: _kind == _ChartKind.pie
                  ? _pie(rows, total)
                  : _bar(rows),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: _palette[i % _palette.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(rows[i].key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      total == 0 ? '' : '${(rows[i].value / total * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 10),
                    Text(formatRinggit(rows[i].value),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(formatRinggit(total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pie(List<MapEntry<String, double>> rows, double total) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 44,
        sections: [
          for (var i = 0; i < rows.length; i++)
            PieChartSectionData(
              value: rows[i].value,
              color: _palette[i % _palette.length],
              radius: 58,
              title: (total > 0 && rows[i].value / total >= 0.06)
                  ? '${(rows[i].value / total * 100).toStringAsFixed(0)}%'
                  : '',
              titleStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _bar(List<MapEntry<String, double>> rows) {
    final maxV = rows.map((e) => e.value).fold<double>(0, (m, v) => v > m ? v : m);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV == 0 ? 1 : maxV * 1.15,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${rows[group.x].key}\n${formatRinggit(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${value.toInt() + 1}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: rows[i].value,
                color: _palette[i % _palette.length],
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }
}
