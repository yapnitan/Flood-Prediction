import 'package:flutter/material.dart';

import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../services/asset_loss_report_service.dart';
import '../../utils/responsive.dart';
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
  String _searchQuery = '';

  static const _statusFilters = ['All', 'Pending Review', 'Verified', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _reportsFuture = _controller.getAdminOverview();
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
    setState(() {
      _reportsFuture = _controller.getAdminOverview();
    });
    await _reportsFuture;
    widget.onReportsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 900, desktop: 1100)),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by asset, address, or category',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusFilters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final value = _statusFilters[index];
                      final selected = _statusFilter == value;
                      return ChoiceChip(
                        label: Text(value),
                        selected: selected,
                        onSelected: (_) => setState(() => _statusFilter = value),
                        selectedColor: Colors.blue.shade100,
                        labelStyle: TextStyle(color: selected ? Colors.blue.shade900 : Colors.black87),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _reportsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Could not load asset loss reports.'));
                        }

                        var rows = snapshot.data ?? [];
                        if (_statusFilter != 'All') {
                          final statusValue = _statusFilter.toLowerCase().replaceAll(' ', '_');
                          rows = rows.where((r) => r['status'] == statusValue).toList();
                        }
                        if (_searchQuery.isNotEmpty) {
                          rows = rows.where((r) {
                            final assetName = (r['asset_name'] as String? ?? '').toLowerCase();
                            final category = (r['asset_category'] as String? ?? '').toLowerCase();
                            final property = r['property'] as Map<String, dynamic>?;
                            final address = (property?['address'] as String? ?? '').toLowerCase();
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

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: rows.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _ReportSummaryCard(
                            data: rows[index],
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AssetLossAdminDetailView(data: rows[index]),
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

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending_review';
    final account = data['account'] as Map<String, dynamic>?;
    final property = data['property'] as Map<String, dynamic>?;
    final estimatedTotal = (data['estimated_total_loss'] as num?)?.toDouble() ?? 0;

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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            if (account != null) ...[
              const SizedBox(height: 4),
              Text('From: ${account['name'] ?? 'Unknown'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
            if (property != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${property['district'] ?? ''}, ${property['state'] ?? ''}',
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
              'Potential loss: RM ${estimatedTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
