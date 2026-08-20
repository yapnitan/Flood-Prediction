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

  /// Reports older than this drop out of the live/community feed
  /// ([getRecent]) automatically — they're still visible in "My Reports"
  /// and the admin history, just no longer part of the "what's happening
  /// right now" view. Pragmatic client-side archival: filtering by age on
  /// read, rather than a scheduled job flipping a status column, since
  /// nothing else in this schema uses pg_cron.
  static const Duration _activeReportWindow = Duration(days: 7);

  Future<List<FloodReport>> getRecent({int limit = 50}) async {
    try {
      final cutoff = DateTime.now().toUtc().subtract(_activeReportWindow);
      final rows = await _supabase
          .from(_table)
          .select()
          .gte('created_at', cutoff.toIso8601String())
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

  Future<FloodReport?> getById(String id) async {
    final data = await _supabase.from(_table).select().eq('id', id).maybeSingle();
    return data == null ? null : FloodReport.fromJson(data);
  }

  /// Overwrites an editable report's fields (own report, still `submitted`
  /// — enforced by RLS, see 0018_flood_report_edit_delete_verify.sql).
  /// [existingPhotoPaths] carries forward photos already on the report
  /// (the edit form doesn't let you remove them, only add more); any
  /// [newPhotos] are uploaded and appended.
  Future<bool> updateReport(
    String id,
    FloodReport report,
    List<String> existingPhotoPaths,
    List<XFile> newPhotos,
  ) async {
    try {
      final newPaths = newPhotos.isEmpty ? <String>[] : await _uploadPhotos(newPhotos);
      await _supabase.from(_table).update({
        'location_name': report.locationName,
        'latitude': report.latitude,
        'longitude': report.longitude,
        'flood_type': report.floodType,
        'water_level': report.waterLevel,
        'observed_at': report.observedAt.toUtc().toIso8601String(),
        'description': report.description,
        'contact_number': report.contactNumber,
        'photo_paths': [...existingPhotoPaths, ...newPaths],
      }).eq('id', id);
      return true;
    } catch (error) {
      debugPrint('FloodReportService.updateReport error: $error');
      return false;
    }
  }

  Future<bool> deleteReport(String id) async {
    try {
      await _supabase.from(_table).delete().eq('id', id);
      return true;
    } catch (error) {
      debugPrint('FloodReportService.deleteReport error: $error');
      return false;
    }
  }

  /// Admin-only (enforced by RLS) — toggles between 'submitted' and
  /// 'verified'. There's no rejection state for reports (unlike repair
  /// requests); an unverified report simply stays 'submitted'.
  Future<bool> setVerified(String id, bool verified) async {
    try {
      await _supabase
          .from(_table)
          .update({'status': verified ? 'verified' : 'submitted'})
          .eq('id', id);
      return true;
    } catch (error) {
      debugPrint('FloodReportService.setVerified error: $error');
      return false;
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
