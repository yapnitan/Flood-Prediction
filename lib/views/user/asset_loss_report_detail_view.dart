import 'package:flutter/material.dart';
import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../models/asset_loss_report.dart';
import '../../services/asset_loss_report_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/responsive.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';
import 'edit_asset_loss_report_view.dart';

/// Read-only view of one of the resident's own asset loss reports —
/// mirrors the info they submitted, plus the helper/admin review outcome
/// once available. While it's still `pending_review` the resident can edit
/// or delete it.
class AssetLossReportDetailView extends StatefulWidget {
  const AssetLossReportDetailView({super.key, required this.reportId});

  final String reportId;

  @override
  State<AssetLossReportDetailView> createState() => _AssetLossReportDetailViewState();
}

class _AssetLossReportDetailViewState extends State<AssetLossReportDetailView> {
  final _controller = AssetLossReportController(AssetLossReportService());

  AssetLossReport? _report;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = await _controller.getReportById(widget.reportId);
    if (!mounted) return;
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  Future<void> _edit() async {
    final report = _report;
    if (report == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditAssetLossReportView(report: report)),
    );
    if (saved == true && mounted) {
      setState(() => _isLoading = true);
      await _load();
    }
  }

  Future<void> _delete() async {
    final report = _report;
    if (report == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    final ok = await _controller.deleteReport(
      report.id!,
      photoPaths: report.photoPaths,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the report. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final canEditOrDelete = report != null && report.isPending;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Asset Loss Report'),
        centerTitle: true,
        actions: [
          if (canEditOrDelete) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _isBusy ? null : _edit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _isBusy ? null : _delete,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : report == null
                ? const Center(child: Text('Report not found.'))
                : Stack(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: context.responsive(
                                  mobile: 700, tablet: 800, desktop: 900)),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: _ReportBody(
                                report: report, controller: _controller),
                          ),
                        ),
                      ),
                      if (_isBusy)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x33000000),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.controller});

  final AssetLossReport report;
  final AssetLossReportController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${report.assetCategory} — ${report.assetName}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            StatusBadge(status: report.status),
          ],
        ),
        const SizedBox(height: 16),
        ReviewCard(
            title: 'Condition',
            value: assetConditionLabels[report.condition] ?? report.condition),
        ReviewCard(title: 'Quantity', value: '${report.quantity}'),
        ReviewCard(
          title: 'Estimated value per item',
          value: formatRinggit(report.estimatedValuePerItem),
        ),
        ReviewCard(
          title: 'Potential Asset Loss',
          value: formatRinggit(report.estimatedTotalLoss ?? 0),
        ),
        if (report.description != null && report.description!.isNotEmpty)
          ReviewCard(title: 'Description', value: report.description!),
        if (report.photoPaths.isNotEmpty) ...[
          const Text('Your Evidence Photos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          _PhotoGrid(paths: report.photoPaths, controller: controller),
          const SizedBox(height: 16),
        ],
        if (report.verificationResult != null) ...[
          const Divider(height: 32),
          const Text('Helper Verification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ReviewCard(
            title: 'Result',
            value: verificationResultLabels[report.verificationResult] ??
                report.verificationResult!,
          ),
          if (report.verifiedTotalLoss != null)
            ReviewCard(
              title: 'Verified loss',
              value: formatRinggit(report.verifiedTotalLoss!),
            ),
          if (report.verificationNotes != null &&
              report.verificationNotes!.isNotEmpty)
            ReviewCard(title: 'Notes', value: report.verificationNotes!),
          if (report.isHelperVerified)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Verified by a helper — awaiting the admin\'s final approval.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
        ],
        if (report.isVerified && report.approvedTotalLoss != null) ...[
          const Divider(height: 32),
          const Text('Admin Approval',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ReviewCard(
            title: 'Approved loss',
            value: formatRinggit(report.approvedTotalLoss!),
          ),
        ],
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.paths, required this.controller});

  final List<String> paths;
  final AssetLossReportController controller;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: paths.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsive(mobile: 3, tablet: 4, desktop: 5),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => NetworkPhotoThumbnail(
        storagePath: paths[index],
        urlResolver: controller.getSignedPhotoUrl,
      ),
    );
  }
}
