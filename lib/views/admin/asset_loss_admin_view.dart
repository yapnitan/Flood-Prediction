import 'package:flutter/material.dart';

import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../services/asset_loss_report_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/malaysia_geocoding.dart';
import '../../utils/responsive.dart';
import '../../widgets/adaptive_search_filter_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'asset_loss_admin_detail_view.dart';

/// Admin's Asset Loss Management page (Task/asset report §10) — replaces
/// the old RepairRequestAdminView. Deliberately has no Scaffold/AppBar of
/// its own, like the other admin tab bodies (admin_view.dart).
class AssetLossAdminView extends StatefulWidget {
  const AssetLossAdminView({super.key, this.onReportsChanged});

  final VoidCallback? onReportsChanged;

  @override
  State<AssetLossAdminView> createState() => _AssetLossAdminViewState();
}

class _AssetLossAdminViewState extends State<AssetLossAdminView> {
  final _controller = AssetLossReportController(AssetLossReportService());
  final _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _reportsFuture;
  String _statusFilter = 'All';
  String _stateFilter = 'all';
  String _searchQuery = '';

  static const _statusFilters = [
    'All',
    'Pending Review',
    'Helper Verified',
    'Verified',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _reportsFuture = _controller.getAdminOverview();
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
      _reportsFuture = _controller.getAdminOverview();
    });
    await _reportsFuture;
    widget.onReportsChanged?.call();
  }

  Future<void> _openReport(Map<String, dynamic> data) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssetLossAdminDetailView(data: data)),
    );
    _refresh();
  }

  // "Unknown state" / "Unknown district" buckets always sort to the bottom.
  static int _unknownLast(String a, String b) {
    final au = a.startsWith('Unknown');
    final bu = b.startsWith('Unknown');
    if (au != bu) return au ? 1 : -1;
    return a.compareTo(b);
  }

  static int _triageOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    int rank(Map<String, dynamic> r) =>
        (r['status'] == 'pending_review' || r['status'] == 'helper_verified')
            ? 0
            : 1;
    final byStatus = rank(a).compareTo(rank(b));
    if (byStatus != 0) return byStatus;
    final av = (a['estimated_total_loss'] as num?)?.toDouble() ?? 0;
    final bv = (b['estimated_total_loss'] as num?)?.toDouble() ?? 0;
    return bv.compareTo(av);
  }

  /// Groups the filtered reports state → district, each as a header row
  /// followed by its cards (pending first, then largest potential loss).
  List<Widget> _buildGrouped(List<Map<String, dynamic>> rows) {
    final byState = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final r in rows) {
      final property = r['property'] as Map<String, dynamic>?;
      final state = (property?['state'] as String?)?.trim();
      final district = (property?['district'] as String?)?.trim();
      final stateKey = (state == null || state.isEmpty)
          ? 'Unknown state'
          : state;
      final districtKey = (district == null || district.isEmpty)
          ? 'Unknown district'
          : district;
      byState
          .putIfAbsent(stateKey, () => {})
          .putIfAbsent(districtKey, () => [])
          .add(r);
    }

    final widgets = <Widget>[];
    final stateKeys = byState.keys.toList()..sort(_unknownLast);
    for (final stateKey in stateKeys) {
      final districts = byState[stateKey]!;
      final stateCount = districts.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      widgets.add(_StateHeader(state: stateKey, count: stateCount));

      final districtKeys = districts.keys.toList()..sort(_unknownLast);
      for (final districtKey in districtKeys) {
        final list = districts[districtKey]!..sort(_triageOrder);
        widgets.add(_DistrictHeader(district: districtKey, count: list.length));
        for (final row in list) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportSummaryCard(
                data: row,
                onTap: () => _openReport(row),
              ),
            ),
          );
        }
      }
    }
    return widgets;
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AdaptiveSearchFilterHeader(
                    searchField: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by asset, address, or category',
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
                          itemCount: _statusFilters.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final value = _statusFilters[index];
                            final selected = _statusFilter == value;
                            return ChoiceChip(
                              label: Text(value),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = value),
                              selectedColor: Colors.blue.shade100,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.blue.shade900
                                    : Colors.black87,
                              ),
                            );
                          },
                        ),
                      ),
                      _buildStateFilterDropdown(),
                    ],
                    sheetTitle: 'Filter asset loss reports',
                    activeFilterCount:
                        (_statusFilter == 'All' ? 0 : 1) +
                        (_stateFilter == 'all' ? 0 : 1),
                    sheetBuilder: (context, setSheetState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final value in _statusFilters)
                              ChoiceChip(
                                label: Text(value),
                                selected: _statusFilter == value,
                                onSelected: (_) {
                                  setState(() => _statusFilter = value);
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
                                  child: Text(_stateLabel(state)),
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
                            child: Text('Could not load asset loss reports.'),
                          );
                        }

                        var rows = snapshot.data ?? [];
                        if (_statusFilter != 'All') {
                          final statusValue = _statusFilter
                              .toLowerCase()
                              .replaceAll(' ', '_');
                          rows = rows
                              .where((r) => r['status'] == statusValue)
                              .toList();
                        }
                        if (_stateFilter != 'all') {
                          rows = rows.where((row) {
                            final property =
                                row['property'] as Map<String, dynamic>?;
                            return property?['state'] == _stateFilter;
                          }).toList();
                        }
                        if (_searchQuery.isNotEmpty) {
                          rows = rows.where((r) {
                            final assetName = (r['asset_name'] as String? ?? '')
                                .toLowerCase();
                            final category =
                                (r['asset_category'] as String? ?? '')
                                    .toLowerCase();
                            final property =
                                r['property'] as Map<String, dynamic>?;
                            final address =
                                (property?['address'] as String? ?? '')
                                    .toLowerCase();
                            return assetName.contains(_searchQuery) ||
                                category.contains(_searchQuery) ||
                                address.contains(_searchQuery);
                          }).toList();
                        }

                        if (rows.isEmpty) {
                          return const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No asset loss reports match this filter.',
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: _buildGrouped(rows),
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

  List<String> get _stateOptions => ['all', ...MalaysiaGeocoder.states];

  String _stateLabel(String state) => state == 'all' ? 'All states' : state;

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
                child: Text(_stateLabel(state)),
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

class _StateHeader extends StatelessWidget {
  const _StateHeader({required this.state, required this.count});

  final String state;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Text(
            '$count report${count == 1 ? '' : 's'}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictHeader extends StatelessWidget {
  const _DistrictHeader({required this.district, required this.count});

  final String district;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 2),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            district,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  /// The specific address/name for this property — state/district already
  /// show in the group header above, so those aren't repeated here.
  static String _propertyLine(Map<String, dynamic>? property) {
    if (property == null) return '';
    final address = (property['address'] as String?)?.trim() ?? '';
    if (address.isNotEmpty) return address;
    return (property['label'] as String?)?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending_review';
    final account = data['account'] as Map<String, dynamic>?;
    final property = data['property'] as Map<String, dynamic>?;
    final estimatedTotal =
        (data['estimated_total_loss'] as num?)?.toDouble() ?? 0;

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
                    '${data['asset_category']} — ${data['asset_name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            if (account != null) ...[
              const SizedBox(height: 4),
              Text(
                'From: ${account['name'] ?? 'Unknown'}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
            if (_propertyLine(property).isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _propertyLine(property),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Condition: ${assetConditionLabels[data['condition']] ?? data['condition']}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Potential loss: ${formatRinggit(estimatedTotal)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
