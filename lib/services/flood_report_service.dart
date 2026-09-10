import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flood_report.dart';
import '../utils/geo_utils.dart';
import 'connectivity_service.dart';
import 'offline_sync_service.dart';

class FloodReportService {
  FloodReportService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const _table = 'flood_report';
  static const _photoBucket = 'flood-report-photos';

  final SupabaseClient _supabase;

  Future<bool> submit(FloodReport report, List<XFile> photos) async {
    final reporterId = _supabase.auth.currentUser?.id;
    if (reporterId == null) {
      debugPrint('FloodReportService.submit error: user is not authenticated');
      return false;
    }

    try {
      final photoPaths = await _uploadPhotos(photos);
      await _supabase
          .from(_table)
          .insert(
            FloodReport(
              reporterId: reporterId,
              locationName: report.locationName,
              latitude: report.latitude,
              longitude: report.longitude,
              state: report.state,
              district: report.district,
              floodType: report.floodType,
              waterLevel: report.waterLevel,
              observedAt: report.observedAt,
              description: report.description,
              contactNumber: report.contactNumber,
              photoPaths: photoPaths,
            ).toJson(),
          );
      return true;
    } catch (error) {
      debugPrint('FloodReportService.submit error: $error');
      return false;
    }
  }

  static const Duration _activeReportWindow = Duration(days: 7);

  static const _cacheKeyRecent = 'flood_report_recent';

  Future<List<FloodReport>> getRecent({int limit = 50}) async {
    if (!ConnectivityService.instance.isOnline) {
      return _reportsFromCache(_cacheKeyRecent);
    }
    try {
      final cutoff = DateTime.now().toUtc().subtract(_activeReportWindow);
      final rows = await _supabase
          .from(_table)
          .select()
          .gte('created_at', cutoff.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(rows as List);
      await OfflineSyncService.instance.cacheList(_cacheKeyRecent, list);
      return list.map((row) => FloodReport.fromJson(row)).toList();
    } catch (error) {
      debugPrint('FloodReportService.getRecent error: $error');
      return _reportsFromCache(_cacheKeyRecent);
    }
  }

  Future<List<FloodReport>> _reportsFromCache(String key) async {
    final cached = await OfflineSyncService.instance.getCachedList(key);
    if (cached == null) return [];
    return cached.map((row) => FloodReport.fromJson(row)).toList();
  }

  Future<FloodReport?> getById(String id) async {
    final data = await _supabase.from(_table).select().eq('id', id).maybeSingle();
    return data == null ? null : FloodReport.fromJson(data);
  }

  Future<bool> updateReport(
    String id,
    FloodReport report,
    List<String> existingPhotoPaths,
    List<XFile> newPhotos,
  ) async {
    try {
      final newPaths = newPhotos.isEmpty ? <String>[] : await _uploadPhotos(newPhotos);
      final rows = await _supabase.from(_table).update({
        'location_name': report.locationName,
        'latitude': report.latitude,
        'longitude': report.longitude,
        'state': report.state,
        'district': report.district,
        'flood_type': report.floodType,
        'water_level': report.waterLevel,
        'observed_at': report.observedAt.toUtc().toIso8601String(),
        'description': report.description,
        'contact_number': report.contactNumber,
        'photo_paths': [...existingPhotoPaths, ...newPaths],
      }).eq('id', id).select();
      if ((rows as List).isEmpty) {
        debugPrint(
          'FloodReportService.updateReport: 0 rows updated for $id — the RLS '
          'update policy is missing (apply migration 0018) or the report is '
          'no longer "submitted".',
        );
        return false;
      }
      return true;
    } catch (error) {
      debugPrint('FloodReportService.updateReport error: $error');
      return false;
    }
  }

  Future<bool> setVerified(String id, bool verified) async {
    try {
      final rows = await _supabase
          .from(_table)
          .update({'status': verified ? 'verified' : 'submitted'})
          .eq('id', id)
          .select();
      if ((rows as List).isEmpty) {
        debugPrint('FloodReportService.setVerified: 0 rows updated for $id');
        return false;
      }
      return true;
    } catch (error) {
      debugPrint('FloodReportService.setVerified error: $error');
      return false;
    }
  }

  Future<bool> deleteReport(String id) async {
    try {
      final rows = await _supabase.from(_table).delete().eq('id', id).select();
      if ((rows as List).isEmpty) {
        debugPrint(
          'FloodReportService.deleteReport: 0 rows deleted for $id — RLS '
          'delete policy missing (migration 0018) or report not "submitted".',
        );
        return false;
      }
      return true;
    } catch (error) {
      debugPrint('FloodReportService.deleteReport error: $error');
      return false;
    }
  }

  Future<List<FloodReport>> getMyReports({int limit = 100}) async {
    final reporterId = _supabase.auth.currentUser?.id;
    if (reporterId == null) return [];
    final cacheKey = 'flood_report_mine_$reporterId';

    if (!ConnectivityService.instance.isOnline) {
      return _reportsFromCache(cacheKey);
    }
    try {
      final rows = await _supabase
          .from(_table)
          .select()
          .eq('reporter_id', reporterId)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(rows as List);
      await OfflineSyncService.instance.cacheList(cacheKey, list);
      return list.map((row) => FloodReport.fromJson(row)).toList();
    } catch (error) {
      debugPrint('FloodReportService.getMyReports error: $error');
      return _reportsFromCache(cacheKey);
    }
  }

  Future<List<Map<String, dynamic>>> getAllReportsWithAccountInfo() async {
    final rows = await _supabase
        .from(_table)
        .select('*, account:reporter_id(name, email)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<FloodReport>> getNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    Duration maxAge = const Duration(hours: 24),
    int limit = 50,
  }) async {
    try {
      final box = GeoBoundingBox.fromCenter(
        lat: latitude,
        lon: longitude,
        radiusKm: radiusKm,
      );
      final since = DateTime.now().toUtc().subtract(maxAge);

      final rows = await _supabase
          .from(_table)
          .select()
          .gte('latitude', box.minLat)
          .lte('latitude', box.maxLat)
          .gte('longitude', box.minLon)
          .lte('longitude', box.maxLon)
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false);

      final reports = (rows as List)
          .map((row) => FloodReport.fromJson(row as Map<String, dynamic>))
          .where(
            (r) =>
                haversineDistanceKm(
                  lat1: latitude,
                  lon1: longitude,
                  lat2: r.latitude,
                  lon2: r.longitude,
                ) <=
                radiusKm,
          )
          .toList();

      return reports.take(limit).toList();
    } catch (error) {
      debugPrint('FloodReportService.getNearby error: $error');
      return [];
    }
  }

  Future<List<String>> getPhotoUrls(
    List<String> paths, {
    int expiresInSeconds = 600,
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
      debugPrint('FloodReportService.getPhotoUrls error: $error');
      return [];
    }
  }

  Future<Map<String, String>> getPhotoUrlsByPath(
    List<String> paths, {
    int expiresInSeconds = 600,
  }) async {
    if (paths.isEmpty) return {};
    try {
      final results = await _supabase.storage
          .from(_photoBucket)
          .createSignedUrlsResult(paths, expiresInSeconds);
      return {
        for (final r in results.whereType<SignedUrlSuccess>())
          r.path: r.signedUrl,
      };
    } catch (error) {
      debugPrint('FloodReportService.getPhotoUrlsByPath error: $error');
      return {};
    }
  }

  Future<List<String>> _uploadPhotos(List<XFile> photos) async {
    final uploadBatch = DateTime.now().microsecondsSinceEpoch.toString();
    final uploaderId = _supabase.auth.currentUser?.id;
    if (uploaderId == null) {
      throw StateError('A signed-in user is required to upload report photos.');
    }
    final paths = <String>[];

    for (var index = 0; index < photos.length; index++) {
      final Uint8List bytes = await photos[index].readAsBytes();
      final path = '$uploaderId/$uploadBatch/photo_$index.jpg';
      await _supabase.storage
          .from(_photoBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      paths.add(path);
    }
    return paths;
  }
}
