import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_loss_report.dart';
import '../services/asset_loss_report_service.dart';

class AssetLossReportController {
  final AssetLossReportService service;

  AssetLossReportController(this.service);

  /// For User

  Future<bool> submit(AssetLossReport report, List<XFile> photos) {
    return service.submit(report, photos);
  }

  Future<List<AssetLossReport>> getMyReports() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    return service.getUserReports(userId);
  }

  Future<AssetLossReport?> getReportById(String reportId) {
    return service.getReportById(reportId);
  }

  /// Resident edits their own still-pending report.
  Future<bool> updateReport(
    String id,
    AssetLossReport report,
    List<String> existingPhotoPaths,
    List<XFile> newPhotos,
  ) {
    return service.updateReport(id, report, existingPhotoPaths, newPhotos);
  }

  /// Resident deletes their own still-pending report (and its photos).
  Future<bool> deleteReport(String id, {List<String> photoPaths = const []}) =>
      service.deleteReport(id, photoPaths: photoPaths);

  Future<String> getSignedPhotoUrl(String path) => service.getSignedPhotoUrl(path);

  Future<List<String>> getSignedPhotoUrls(List<String> paths) =>
      service.getSignedPhotoUrls(paths);

  /// For Admin

  Future<List<Map<String, dynamic>>> getAdminOverview() => service.getAdminOverview();

  Future<void> approve({
    required String reportId,
    required int approvedQuantity,
    required double approvedValuePerItem,
  }) {
    return service.adminApprove(
      reportId: reportId,
      approvedQuantity: approvedQuantity,
      approvedValuePerItem: approvedValuePerItem,
    );
  }

  Future<void> reject(String reportId) => service.adminReject(reportId);

  /// For Helper

  Future<List<Map<String, dynamic>>> getMyDistrictReports() => service.getHelperDistrictReports();

  Future<void> submitVerification({
    required String reportId,
    required int verifiedQuantity,
    required double verifiedValuePerItem,
    required String verifiedCondition,
    required String verificationResult,
    String? verificationNotes,
    List<XFile> verificationPhotos = const [],
    required String reportOwnerId,
  }) async {
    var paths = <String>[];
    if (verificationPhotos.isNotEmpty) {
      paths = await service.uploadVerificationPhotos(
        reportOwnerId: reportOwnerId,
        reportId: reportId,
        photos: verificationPhotos,
      );
    }
    await service.submitHelperVerification(
      reportId: reportId,
      verifiedQuantity: verifiedQuantity,
      verifiedValuePerItem: verifiedValuePerItem,
      verifiedCondition: verifiedCondition,
      verificationResult: verificationResult,
      verificationNotes: verificationNotes,
      verificationPhotoPaths: paths,
    );
  }
}
