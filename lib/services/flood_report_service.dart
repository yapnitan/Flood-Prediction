import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flood_report.dart';
import '../utils/geo_utils.dart';

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

  Future<List<FloodReport>> getRecent({int limit = 50}) async {
    try {
      final rows = await _supabase
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((row) => FloodReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('FloodReportService.getRecent error: $error');
      return [];
    }
  }

  /// Reports submitted by the currently authenticated user, most recent
  /// first — backs the Report History page. Errors propagate (rather than
  /// being swallowed like [getRecent]/[getNearby]) so the page can tell
  /// "load failed" apart from "no reports yet".
  Future<List<FloodReport>> getMyReports({int limit = 100}) async {
    final reporterId = _supabase.auth.currentUser?.id;
    if (reporterId == null) return [];

    final rows = await _supabase
        .from(_table)
        .select()
        .eq('reporter_id', reporterId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((row) => FloodReport.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Every flood report, most recent first, joined with the reporter's
  /// account so the admin list can show who submitted each one. Relies on
  /// the "Administrators can read flood reports" RLS policy (0004 migration)
  /// to see reports beyond the caller's own — same join pattern as
  /// [RepairRequestService.getAllRequestsWithAccountInfo].
  Future<List<Map<String, dynamic>>> getAllReportsWithAccountInfo() async {
    final rows = await _supabase
        .from(_table)
        .select('*, account:reporter_id(name, email)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Reports within [radiusKm] of the given coordinates, reported within
  /// the last [maxAge] — a live "what's happening near here right now"
  /// signal, as opposed to [getRecent]'s global recent-reports list.
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

  /// Signed, time-limited URLs for a report's evidence photos — the
  /// `flood-report-photos` bucket is private, so a plain public URL
  /// won't work; each viewer needs their own freshly-signed one. Paths
  /// the caller isn't allowed to read (RLS) are silently omitted rather
  /// than failing the whole batch.
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
