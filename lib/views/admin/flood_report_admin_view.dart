import 'package:flutter/material.dart';

import '../../controllers/flood_report_controller.dart';
import '../../models/flood_report.dart';
import '../../services/flood_report_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/status_badge.dart';
import '../user/report_detail_view.dart';

/// Admin-facing list of every flood report submitted by residents, with
/// filtering by flood type/water level. Reuses [FloodReport],
/// [FloodReportController], [StatusBadge], and [ReportDetailView] — the
/// same model, controller, and detail page the resident-facing Report
/// History flow already uses — rather than duplicating them for admin.
///
/// Deliberately has no [Scaffold]/[AppBar] of its own — like
/// `RepairRequestAdminView`, it's swapped in as the body of [AdminHome]'s
/// existing shell (`admin_view.dart`), so the "Recovery"/"Flood Reports"
/// screen shares the exact same app bar styling and bottom navigation bar
/// as the rest of the admin section instead of a separate, pushed page.
class FloodReportAdminView extends StatefulWidget {
  const FloodReportAdminView({super.key});

  @override
  State<FloodReportAdminView> createState() => _FloodReportAdminViewState();
}

class _FloodReportAdminViewState extends State<FloodReportAdminView> {
  final _controller = FloodReportController(FloodReportService());

  late Future<List<Map<String, dynamic>>> _reportsFuture;
  String _floodTypeFilter = 'all';
  String _waterLevelFilter = 'all';

  // Same options offered on the submission form (submit_report.dart), so
  // the filter values always line up with what a report can actually have.
  final List<String> _floodTypeOptions = [
    'all',
    'Street Flooding',
    'River Overflow',
    'Drainage Issue',
    'Other',
  ];
  final List<String> _waterLevelOptions = ['all', 'Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _reportsFuture = _controller.getAdminOverview();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    // Block body, not `=> expr` — an arrow body would make the assignment's
    // *value* (a Future) the closure's return value, and setState() only
    // accepts callbacks returning void.
    setState(() {
      _reportsFuture = _controller.getAdminOverview();
    });
    await _reportsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(
                mobile: 700,
                tablet: 900,
                desktop: 1100,
              ),
            ),
            child: Column(
              children: [
                _buildFilterBar(
                  options: _floodTypeOptions,
                  selected: _floodTypeFilter,
                  onSelected: (value) =>
                      setState(() => _floodTypeFilter = value),
                  labelBuilder: (value) => value == 'all' ? 'All types' : value,
                ),
                _buildFilterBar(
                  options: _waterLevelOptions,
                  selected: _waterLevelFilter,
                  onSelected: (value) =>
                      setState(() => _waterLevelFilter = value),
                  labelBuilder: (value) =>
                      value == 'all' ? 'All water levels' : value,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _reportsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Could not load flood reports.'),
                          );
                        }

                        var rows = snapshot.data ?? [];
                        if (_floodTypeFilter != 'all') {
                          rows = rows
                              .where((r) => r['flood_type'] == _floodTypeFilter)
                              .toList();
                        }
                        if (_waterLevelFilter != 'all') {
                          rows = rows
                              .where(
                                (r) => r['water_level'] == _waterLevelFilter,
                              )
                              .toList();
                        }

                        if (rows.isEmpty) {
                          return const Center(
                            child: Text('No flood reports match this filter.'),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: rows.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final report = FloodReport.fromJson(rows[index]);
                            final account =
                                rows[index]['account'] as Map<String, dynamic>?;
                            final reporterName = account?['name'] as String?;
                            return _AdminReportSummaryCard(
                              report: report,
                              reporterName: reporterName,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ReportDetailView(
                                    report: report,
                                    reporterName: reporterName,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    required String Function(String) labelBuilder,
  }) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = options[index];
          final isSelected = selected == value;
          return ChoiceChip(
            label: Text(labelBuilder(value)),
            selected: isSelected,
            onSelected: (_) => onSelected(value),
            selectedColor: Colors.blue.shade100,
            labelStyle: TextStyle(
              color: isSelected ? Colors.blue.shade900 : Colors.black87,
            ),
          );
        },
      ),
    );
  }
}

class _AdminReportSummaryCard extends StatelessWidget {
  const _AdminReportSummaryCard({
    required this.report,
    required this.reporterName,
    required this.onTap,
  });

  final FloodReport report;
  final String? reporterName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    report.floodType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(status: report.status),
              ],
            ),
            if (reporterName != null && reporterName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'From: $reporterName',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.locationName,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Water level: ${report.waterLevel}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.description,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(report.createdAt ?? report.observedAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
