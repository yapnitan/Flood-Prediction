import 'package:image_picker/image_picker.dart';

import '../models/flood_report.dart';
import '../services/flood_report_service.dart';

class FloodReportController {
  final FloodReportService floodReportService;

  FloodReportController(this.floodReportService);

  Future<bool> submit(FloodReport report, List<XFile> photos) {
    return floodReportService.submit(report, photos);
  }

  Future<List<FloodReport>> getRecent({int limit = 50}) {
    return floodReportService.getRecent(limit: limit);
  }

  Future<List<FloodReport>> getMyReports({int limit = 100}) {
    return floodReportService.getMyReports(limit: limit);
  }

  Future<FloodReport?> getById(String id) {
    return floodReportService.getById(id);
  }

  Future<bool> updateReport(
    String id,
    FloodReport report,
    List<String> existingPhotoPaths,
    List<XFile> newPhotos,
  ) {
    return floodReportService.updateReport(id, report, existingPhotoPaths, newPhotos);
  }

  Future<bool> deleteReport(String id) {
    return floodReportService.deleteReport(id);
  }

  /// For Admin
  Future<List<Map<String, dynamic>>> getAdminOverview() {
    return floodReportService.getAllReportsWithAccountInfo();
  }

  Future<bool> setVerified(String id, bool verified) {
    return floodReportService.setVerified(id, verified);
  }

  Future<List<FloodReport>> getNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    Duration maxAge = const Duration(hours: 24),
    int limit = 50,
  }) {
    return floodReportService.getNearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      maxAge: maxAge,
      limit: limit,
    );
  }
}
