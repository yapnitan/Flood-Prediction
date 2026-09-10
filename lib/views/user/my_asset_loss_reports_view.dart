import 'package:flutter/material.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../models/asset_loss_report.dart';
import '../../services/asset_loss_report_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'asset_loss_report_detail_view.dart';

class MyAssetLossReportsView extends StatefulWidget {
  const MyAssetLossReportsView({super.key});

  @override
  State<MyAssetLossReportsView> createState() => _MyAssetLossReportsViewState();
}

class _MyAssetLossReportsViewState extends State<MyAssetLossReportsView> {
  final _controller = AssetLossReportController(AssetLossReportService());
  late Future<List<AssetLossReport>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _controller.getMyReports();
  }

  Future<void> _refresh() async {
    setState(() {
      _reportsFuture = _controller.getMyReports();
    });
    await _reportsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('My Asset Loss Reports'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<AssetLossReport>>(
                future: _reportsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load your reports',
                      subtitle: 'Pull down to try again.',
                    );
                  }

                  final reports = snapshot.data ?? [];
                  if (reports.isEmpty) {
                    return const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No asset loss reports yet',
                      subtitle: 'Reports you submit will show up here.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reports.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ReportCard(
                      report: reports[index],
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AssetLossReportDetailView(reportId: reports[index].id!),
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
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final AssetLossReport report;
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
                    '${report.assetCategory} — ${report.assetName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(status: report.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Potential loss: ${formatRinggit(report.estimatedTotalLoss ?? 0)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (report.isVerified && report.approvedTotalLoss != null) ...[
              const SizedBox(height: 4),
              Text(
                'Approved: ${formatRinggit(report.approvedTotalLoss!)}',
                style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
            if (report.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(_formatDate(report.createdAt!), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
