import 'package:flutter/material.dart';
import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../models/asset_loss_report.dart';
import '../../services/asset_loss_report_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';

/// Read-only view of one of the resident's own asset loss reports —
/// mirrors the info they submitted, plus the helper/admin review outcome
/// once available.
class AssetLossReportDetailView extends StatefulWidget {
  const AssetLossReportDetailView({super.key, required this.reportId});

  final String reportId;

  @override
  State<AssetLossReportDetailView> createState() => _AssetLossReportDetailViewState();
}

class _AssetLossReportDetailViewState extends State<AssetLossReportDetailView> {
  final _controller = AssetLossReportController(AssetLossReportService());
  late Future<AssetLossReport?> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _controller.getReportById(widget.reportId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Asset Loss Report'), centerTitle: true),
      body: SafeArea(
        child: FutureBuilder<AssetLossReport?>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final report = snapshot.data;
            if (report == null) {
              return const Center(child: Text('Report not found.'));
            }

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
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
                      ReviewCard(title: 'Condition', value: assetConditionLabels[report.condition] ?? report.condition),
                      ReviewCard(title: 'Quantity', value: '${report.quantity}'),
                      ReviewCard(
                        title: 'Estimated value per item',
                        value: 'RM ${report.estimatedValuePerItem.toStringAsFixed(2)}',
                      ),
                      ReviewCard(
                        title: 'Potential Asset Loss',
                        value: 'RM ${(report.estimatedTotalLoss ?? 0).toStringAsFixed(2)}',
                      ),
                      if (report.description != null && report.description!.isNotEmpty)
                        ReviewCard(title: 'Description', value: report.description!),
                      if (report.photoPaths.isNotEmpty) ...[
                        const Text('Your Evidence Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        _PhotoGrid(paths: report.photoPaths, controller: _controller),
                        const SizedBox(height: 16),
                      ],
                      if (report.verificationResult != null) ...[
                        const Divider(height: 32),
                        const Text('Helper Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        ReviewCard(
                          title: 'Result',
                          value: verificationResultLabels[report.verificationResult] ?? report.verificationResult!,
                        ),
                        if (report.verifiedTotalLoss != null)
                          ReviewCard(
                            title: 'Verified loss',
                            value: 'RM ${report.verifiedTotalLoss!.toStringAsFixed(2)}',
                          ),
                        if (report.verificationNotes != null && report.verificationNotes!.isNotEmpty)
                          ReviewCard(title: 'Notes', value: report.verificationNotes!),
                      ],
                      if (report.isVerified && report.approvedTotalLoss != null) ...[
                        const Divider(height: 32),
                        const Text('Admin Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        ReviewCard(
                          title: 'Approved loss',
                          value: 'RM ${report.approvedTotalLoss!.toStringAsFixed(2)}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
