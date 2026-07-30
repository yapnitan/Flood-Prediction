import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flood_report.dart';

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
      await _supabase.storage.from(_photoBucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
      paths.add(path);
    }
    return paths;
  }
}
