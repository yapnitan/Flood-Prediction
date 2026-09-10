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

  /// Two-phase so each report's photos land in their *own* folder, keyed by
  /// the report's UUID: insert the row, then upload to
  /// `{userId}/{reportId}/photo_N.jpg`, then set `photo_paths`.
  ///
  /// The old scheme keyed the folder on `DateTime.now().microsecondsSinceEpoch`,
  /// which collided when several items in one report were submitted back-to-back
  /// in a loop — so one item's photos leaked onto another. It also didn't match
  /// the `{ownerId}/{reportId}/...` path the assigned-helper storage policy
  /// (0025) checks, so helpers couldn't see any evidence photos.
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
      // The report itself is saved — don't fail the whole submission (and
      // don't have the caller re-submit, which would duplicate the row).
      debugPrint(
        'AssetLossReportService.submit: report $reportId saved without photos: $error',
      );
    }
    return true;
  }

  Future<List<String>> _uploadPhotos(
    String userId,
    String reportId,
    List<XFile> photos,
  ) async {
    final paths = <String>[];
    for (var index = 0; index < photos.length; index++) {
      try {
        final bytes = await photos[index].readAsBytes();
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

  /// Verification photos live under the report's own folder (so the
  /// district-assigned-helper storage policy can match on it), in a
  /// `verification/` subfolder so they're distinguishable from the
  /// resident's own evidence photos in the same bucket.
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

  Future<String> getSignedPhotoUrl(String path, {int expiresInSeconds = 3600}) async {
    try {
      return await _supabase.storage
          .from(_photoBucket)
          .createSignedUrl(path, expiresInSeconds);
    } catch (error) {
      // Usually a storage-RLS denial: the caller lacks `select` on this
      // object. Admins need the "Admins can view all asset loss photos"
      // policy on storage.objects (migration 0023); assigned helpers need
      // the district-scoped one (migration 0025).
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

  /// Admin overview — joined with the reporter's account, the property/
  /// address, and the flood incident (if any) so the admin list/filter view
  /// doesn't need N+1 lookups. Rows are plain maps (not [AssetLossReport])
  /// since they carry joined fields the model doesn't have.
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

  /// A helper only ever gets back rows RLS lets them see — i.e. reports
  /// whose address falls in one of their active district assignments
  /// (0025_asset_loss_helper_district_scoping.sql) — no client-side
  /// district filtering needed on top of this.
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
      'verified_quantity': verifiedQuantity,
      'verified_value_per_item': verifiedValuePerItem,
      'verified_condition': verifiedCondition,
      'verification_result': verificationResult,
      'verification_notes': verificationNotes,
      'verification_photo_paths': verificationPhotoPaths,
      'verified_by': helperId,
      'verified_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId);
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
