import 'package:flutter/material.dart';

import '../../controllers/flood_report_controller.dart';
import '../../models/flood_report.dart';
import '../../services/flood_report_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'report_detail_view.dart';

/// Lists the currently authenticated user's own flood report submissions,
/// most recent first — opened from the "Report History" tile on the
/// Profile page.
class ReportHistoryView extends StatefulWidget {
  const ReportHistoryView({super.key});

  @override
  State<ReportHistoryView> createState() => _ReportHistoryViewState();
}

class _ReportHistoryViewState extends State<ReportHistoryView> {
  final _controller = FloodReportController(FloodReportService());
  final _searchController = TextEditingController();
  late Future<List<FloodReport>> _reportsFuture;

  String _searchQuery = '';
  String _waterLevelFilter = 'All';
  static const _waterLevelOptions = ['All', 'Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _reportsFuture = _controller.getMyReports();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // Block body, not `=> expr` — an arrow body would make the assignment's
    // *value* (a Future) the closure's return value, and setState() only
    // accepts callbacks returning void.
    setState(() {
      _reportsFuture = _controller.getMyReports();
    });
    await _reportsFuture;
  }

  List<FloodReport> _applyFilters(List<FloodReport> reports) {
    return reports.where((r) {
      if (_waterLevelFilter != 'All' && r.waterLevel != _waterLevelFilter) return false;
      if (_searchQuery.isEmpty) return true;
      return r.locationName.toLowerCase().contains(_searchQuery) ||
          r.description.toLowerCase().contains(_searchQuery) ||
          r.floodType.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = context.isKeyboardVisible;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Report History'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(
                mobile: 700,
                tablet: 800,
                desktop: 900,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by location, type, or description',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _searchController.clear,
                            ),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (!keyboardVisible)
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: _waterLevelOptions.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final level = _waterLevelOptions[index];
                      final selected = _waterLevelFilter == level;
                      return ChoiceChip(
                        label: Text(level == 'All' ? 'All water levels' : level),
                        selected: selected,
                        onSelected: (_) => setState(() => _waterLevelFilter = level),
                      );
                    },
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<FloodReport>>(
                      future: _reportsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return const EmptyState(
                            icon: Icons.error_outline,
                            title: 'Could not load your report history',
                            subtitle: 'Pull down to try again.',
                          );
                        }

                        final reports = _applyFilters(snapshot.data ?? []);
                        if (reports.isEmpty) {
                          return const EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'No reports found.',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: reports.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _ReportCard(
                            report: reports[index],
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReportDetailView(report: reports[index]),
                                ),
                              );
                              _refresh();
                            },
                          ),
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

}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final FloodReport report;
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
