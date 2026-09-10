import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/flood_report_controller.dart';
import '../../models/flood_report.dart';
import '../../services/flood_report_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/photo_gallery_viewer.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';
import 'submit_report.dart';

/// Full detail view for a single flood report, opened by tapping a card in
/// [ReportHistoryView] (the reporting user) or the admin flood report list
/// (`FloodReportAdminView`). Mostly a read-only layout plus the uploaded
/// evidence photos, but also hosts edit/delete for the report's own
/// reporter (while still `submitted`) and verify/unverify for admins.
class ReportDetailView extends StatefulWidget {
  const ReportDetailView({super.key, required this.report, this.reporterName});

  final FloodReport report;

  /// Only passed by the admin view, which already has it from the
  /// reporter-account join — the reporting user obviously knows it's their
  /// own report, so [ReportHistoryView] never needs to pass this. Doubles
  /// as the "am I looking at this as an admin" flag.
  final String? reporterName;

  @override
  State<ReportDetailView> createState() => _ReportDetailViewState();
}

class _ReportDetailViewState extends State<ReportDetailView> {
  final _controller = FloodReportController(FloodReportService());
  final _service = FloodReportService();

  late FloodReport _report;
  bool _isBusy = false;

  bool get _isAdminViewer => widget.reporterName != null;
  bool get _isOwner =>
      _report.reporterId != null &&
      _report.reporterId == Supabase.instance.client.auth.currentUser?.id;
  bool get _canEditOrDelete => _isOwner && _report.status == 'submitted';

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SubmitReportPage(existing: _report)),
    );
    if (updated != true || !mounted) return;
    setState(() => _isBusy = true);
    final fresh = await _controller.getById(_report.id!);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (fresh != null) _report = fresh;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
    final ok = await _controller.deleteReport(_report.id!);
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
    final service = _service;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Report Details'),
        centerTitle: true,
        actions: [
          if (_canEditOrDelete) ...[
            IconButton(
              tooltip: 'Edit report',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _isBusy ? null : _edit,
            ),
            IconButton(
              tooltip: 'Delete report',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isBusy ? null : _delete,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isBusy,
          child: Stack(
            children: [
              Center(
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
                      if (!_isAdminViewer)
                        StatusBadge(status: report.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.reporterName != null && widget.reporterName!.isNotEmpty)
                    ReviewCard(title: 'Reported by', value: widget.reporterName!),
                  ReviewCard(title: 'Location', value: report.locationName),
                  if ((report.district ?? '').isNotEmpty ||
                      (report.state ?? '').isNotEmpty)
                    ReviewCard(
                      title: 'Area',
                      value: [
                        if ((report.district ?? '').isNotEmpty) report.district!,
                        if ((report.state ?? '').isNotEmpty) report.state!,
                      ].join(', '),
                    ),
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
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: context.responsive(mobile: 3, tablet: 4, desktop: 5),
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
