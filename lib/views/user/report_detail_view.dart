import 'package:flutter/material.dart';

import '../../models/flood_report.dart';
import '../../services/flood_report_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/photo_gallery_viewer.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';

/// Full detail view for a single flood report, opened by tapping a card in
/// [ReportHistoryView] (the reporting user) or the admin flood report list
/// (`FloodReportAdminView`). Read-only — the report itself is already in
/// memory, so this just lays it out in full plus the uploaded evidence
/// photos.
class ReportDetailView extends StatelessWidget {
  const ReportDetailView({super.key, required this.report, this.reporterName});

  final FloodReport report;

  /// Only passed by the admin view, which already has it from the
  /// reporter-account join — the reporting user obviously knows it's their
  /// own report, so [ReportHistoryView] never needs to pass this.
  final String? reporterName;

  @override
  Widget build(BuildContext context) {
    final service = FloodReportService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Report Details'), centerTitle: true),
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
                          report.floodType,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusBadge(status: report.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (reporterName != null && reporterName!.isNotEmpty)
                    ReviewCard(title: 'Reported by', value: reporterName!),
                  ReviewCard(title: 'Location', value: report.locationName),
                  ReviewCard(title: 'Water level', value: report.waterLevel),
                  ReviewCard(
                    title: 'Observed at',
                    value: _formatDateTime(report.observedAt),
                  ),
                  ReviewCard(title: 'Description', value: report.description),
                  if (report.contactNumber != null &&
                      report.contactNumber!.isNotEmpty)
                    ReviewCard(
                      title: 'Contact number',
                      value: report.contactNumber!,
                    ),
                  if (report.createdAt != null)
                    ReviewCard(
                      title: 'Submitted',
                      value: _formatDateTime(report.createdAt!),
                    ),

                  const SizedBox(height: 12),
                  const Text(
                    'Photos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  if (report.photoPaths.isEmpty)
                    const Text(
                      'No photos attached',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    FutureBuilder<List<String>>(
                      future: service.getPhotoUrls(report.photoPaths),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final urls = snapshot.data ?? [];
                        if (urls.isEmpty) {
                          return const Text(
                            'Photos unavailable',
                            style: TextStyle(color: Colors.grey),
                          );
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: urls.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemBuilder: (context, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => PhotoGalleryViewer(
                                    urls: urls,
                                    initialIndex: index,
                                  ),
                                ),
                              ),
                              child: Image.network(
                                urls[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const ColoredBox(
                                      color: Color(0xFFF2F2F2),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final d =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final t =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }
}
