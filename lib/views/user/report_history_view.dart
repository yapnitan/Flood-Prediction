import 'package:flutter/material.dart';

import '../../controllers/flood_report_controller.dart';
import '../../models/flood_report.dart';
import '../../services/flood_report_service.dart';
import '../../utils/malaysia_geocoding.dart';
import '../../utils/responsive.dart';
import '../../widgets/adaptive_search_filter_header.dart';
import '../../widgets/empty_state.dart';
import 'report_detail_view.dart';

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
  String _floodTypeFilter = 'All';
  String _stateFilter = 'All';
  static const _waterLevelOptions = ['All', 'Low', 'Medium', 'High'];

  static const _floodTypeOptions = [
    'All',
    'Street Flooding',
    'River Overflow',
    'Drainage Issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reportsFuture = _controller.getMyReports();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {

    setState(() {
      _reportsFuture = _controller.getMyReports();
    });
    await _reportsFuture;
  }

  List<FloodReport> _applyFilters(List<FloodReport> reports) {
    return reports.where((r) {
      if (_waterLevelFilter != 'All' && r.waterLevel != _waterLevelFilter)
        return false;
      if (_floodTypeFilter != 'All' && r.floodType != _floodTypeFilter)
        return false;
      if (_stateFilter != 'All' && r.state != _stateFilter) return false;
      if (_searchQuery.isEmpty) return true;
      return r.locationName.toLowerCase().contains(_searchQuery) ||
          r.description.toLowerCase().contains(_searchQuery) ||
          r.floodType.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<String> get _stateOptions => ['All', ...MalaysiaGeocoder.states];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
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
                  child: AdaptiveSearchFilterHeader(
                    searchField: TextField(
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    portraitFilters: [
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _floodTypeOptions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final type = _floodTypeOptions[index];
                            final selected = _floodTypeFilter == type;
                            return ChoiceChip(
                              label: Text(type == 'All' ? 'All types' : type),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _floodTypeFilter = type),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: _waterLevelOptions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final level = _waterLevelOptions[index];
                            final selected = _waterLevelFilter == level;
                            return ChoiceChip(
                              label: Text(
                                level == 'All' ? 'All water levels' : level,
                              ),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _waterLevelFilter = level),
                            );
                          },
                        ),
                      ),
                      _buildStateFilterDropdown(),
                    ],
                    sheetTitle: 'Filter report history',
                    activeFilterCount:
                        (_floodTypeFilter == 'All' ? 0 : 1) +
                        (_waterLevelFilter == 'All' ? 0 : 1) +
                        (_stateFilter == 'All' ? 0 : 1),
                    sheetBuilder: (context, setSheetState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Flood type',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in _floodTypeOptions)
                              ChoiceChip(
                                label: Text(type == 'All' ? 'All types' : type),
                                selected: _floodTypeFilter == type,
                                onSelected: (_) {
                                  setState(() => _floodTypeFilter = type);
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Water level',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final level in _waterLevelOptions)
                              ChoiceChip(
                                label: Text(
                                  level == 'All' ? 'All water levels' : level,
                                ),
                                selected: _waterLevelFilter == level,
                                onSelected: (_) {
                                  setState(() => _waterLevelFilter = level);
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'State',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey('sheet-state-$_stateFilter'),
                          initialValue: _stateFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _stateOptions
                              .map(
                                (state) => DropdownMenuItem(
                                  value: state,
                                  child: Text(
                                    state == 'All' ? 'All states' : state,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (state) {
                            if (state == null) return;
                            setState(() => _stateFilter = state);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<FloodReport>>(
                      future: _reportsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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

  Widget _buildStateFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey('page-state-$_stateFilter'),
        initialValue: _stateFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'State',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _stateOptions
            .map(
              (state) => DropdownMenuItem(
                value: state,
                child: Text(state == 'All' ? 'All states' : state),
              ),
            )
            .toList(),
        onChanged: (state) {
          if (state != null) setState(() => _stateFilter = state);
        },
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
            Text(
              report.floodType,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
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
