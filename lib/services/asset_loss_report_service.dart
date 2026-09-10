import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_loss_report.dart';

class AssetLossReportService {
  AssetLossReportService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'asset_loss_report';
  static const _photoBucket = 'asset-loss-photos';

  final SupabaseClient _supabase;

  Future<bool> submit(AssetLossReport report, List<XFile> photos) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('AssetLossReportService.submit error: user is not authenticated');
      return false;
    }

    String reportId;
    try {
      final row = await _supabase
          .from(_table)
          .insert(
            AssetLossReport(
              userId: userId,
              propertyId: report.propertyId,
              floodIncidentId: report.floodIncidentId,
              assetCategory: report.assetCategory,
              assetName: report.assetName,
              condition: report.condition,
              quantity: report.quantity,
              estimatedValuePerItem: report.estimatedValuePerItem,
              description: report.description,
              photoPaths: const [],
            ).toJson(),
          )
          .select('id')
          .single();
      reportId = row['id'] as String;
    } catch (error) {
      debugPrint('AssetLossReportService.submit insert error: $error');
      return false;
    }

    if (photos.isEmpty) return true;

    try {
      final paths = await _uploadPhotos(userId, reportId, photos);
      if (paths.isNotEmpty) {
        await _supabase
            .from(_table)
            .update({'photo_paths': paths}).eq('id', reportId);
      }
    } catch (error) {

      debugPrint(
        'AssetLossReportService.submit: report $reportId saved without photos: $error',
      );
    }
    return true;
  }

  Future<bool> updateReport(
    String id,
    AssetLossReport report,
    List<String> existingPhotoPaths,
    List<XFile> newPhotos,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      var photoPaths = existingPhotoPaths;
      if (newPhotos.isNotEmpty) {
        final uploaded = await _uploadPhotos(
          userId,
          id,
          newPhotos,
          startIndex: existingPhotoPaths.length,
        );
        photoPaths = [...existingPhotoPaths, ...uploaded];
      }
      await _supabase.from(_table).update({
        'asset_category': report.assetCategory,
        'asset_name': report.assetName,
        'condition': report.condition,
        'quantity': report.quantity,
        'estimated_value_per_item': report.estimatedValuePerItem,
        'description': report.description,
        'flood_incident_id': report.floodIncidentId,
        'photo_paths': photoPaths,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (error) {
      debugPrint('AssetLossReportService.updateReport error: $error');
      return false;
    }
  }

  Future<bool> deleteReport(String id, {List<String> photoPaths = const []}) async {
    try {

      final deleted = await _supabase.from(_table).delete().eq('id', id).select();
      if ((deleted as List).isEmpty) {
        debugPrint(
          'AssetLossReportService.deleteReport: nothing deleted for $id '
          '(RLS blocked or already gone)',
        );
        return false;
      }
      if (photoPaths.isNotEmpty) {

        try {
          await _supabase.storage.from(_photoBucket).remove(photoPaths);
        } catch (error) {
          debugPrint('AssetLossReportService.deleteReport photo cleanup: $error');
        }
      }
      return true;
    } catch (error) {
      debugPrint('AssetLossReportService.deleteReport error: $error');
      return false;
    }
  }

  Future<List<String>> _uploadPhotos(
    String userId,
    String reportId,
    List<XFile> photos, {
    int startIndex = 0,
  }) async {
    final paths = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final index = startIndex + i;
      try {
        final bytes = await photos[i].readAsBytes();
        final path = '$userId/$reportId/photo_$index.jpg';
        await _supabase.storage.from(_photoBucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        paths.add(path);
      } catch (error) {
        debugPrint('AssetLossReportService._uploadPhotos: photo $index failed: $error');
      }
    }
    return paths;
  }

  Future<List<String>> uploadVerificationPhotos({
    required String reportOwnerId,
    required String reportId,
    required List<XFile> photos,
  }) async {
    final batch = DateTime.now().microsecondsSinceEpoch.toString();
    final paths = <String>[];
    for (var index = 0; index < photos.length; index++) {
      final bytes = await photos[index].readAsBytes();
      final path = '$reportOwnerId/$reportId/verification/$batch/photo_$index.jpg';
      await _supabase.storage.from(_photoBucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      paths.add(path);
    }
    return paths;
  }

  Future<List<String>> getSignedPhotoUrls(
    List<String> paths, {
    int expiresInSeconds = 3600,
  }) async {
    if (paths.isEmpty) return [];
    try {
      final results = await _supabase.storage
          .from(_photoBucket)
          .createSignedUrlsResult(paths, expiresInSeconds);
      return results
          .whereType<SignedUrlSuccess>()
          .map((r) => r.signedUrl)
          .toList();
    } catch (error) {
      debugPrint('AssetLossReportService.getSignedPhotoUrls error: $error');
      return [];
    }
  }

  Future<String> getSignedPhotoUrl(String path, {int expiresInSeconds = 3600}) async {
    try {
      return await _supabase.storage
          .from(_photoBucket)
          .createSignedUrl(path, expiresInSeconds);
    } catch (error) {

      debugPrint('AssetLossReportService.getSignedPhotoUrl($path) failed: $error');
      rethrow;
    }
  }

  Future<List<AssetLossReport>> getUserReports(String userId) async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => AssetLossReport.fromJson(e)).toList();
  }

  Future<AssetLossReport?> getReportById(String reportId) async {
    final data = await _supabase.from(_table).select().eq('id', reportId).maybeSingle();
    return data == null ? null : AssetLossReport.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getAdminOverview() async {
    final data = await _supabase
        .from(_table)
        .select(
          '*, account:user_id(name, email), '
          'property:property_id(label, address, state, district, lat, lng), '
          'flood_incident:flood_incident_id(name)',
        )
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getHelperDistrictReports() async {
    final data = await _supabase
        .from(_table)
        .select('*, property:property_id(label, address, state, district, lat, lng)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> submitHelperVerification({
    required String reportId,
    required int verifiedQuantity,
    required double verifiedValuePerItem,
    required String verifiedCondition,
    required String verificationResult,
    String? verificationNotes,
    List<String> verificationPhotoPaths = const [],
  }) async {
    final helperId = _supabase.auth.currentUser?.id;
    await _supabase.from(_table).update({
      'status': 'helper_verified',
      'verified_quantity': verifiedQuantity,
      'verified_value_per_item': verifiedValuePerItem,
      'verified_condition': verifiedCondition,
      'verification_result': verificationResult,
      'verification_notes': verificationNotes,
      'verification_photo_paths': verificationPhotoPaths,
      'verified_by': helperId,
      'verified_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId).eq('status', 'pending_review');
  }

  Future<void> adminApprove({
    required String reportId,
    required int approvedQuantity,
    required double approvedValuePerItem,
  }) async {
    final adminId = _supabase.auth.currentUser?.id;
    await _supabase.from(_table).update({
      'status': 'verified',
      'approved_quantity': approvedQuantity,
      'approved_value_per_item': approvedValuePerItem,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': adminId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
  }

  Future<void> adminReject(String reportId) async {
    final adminId = _supabase.auth.currentUser?.id;
    await _supabase.from(_table).update({
      'status': 'rejected',
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': adminId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
  }
}
