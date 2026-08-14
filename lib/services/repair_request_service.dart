import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/repair_request.dart';

class RepairRequestService {
  RepairRequestService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'repair_request';
  static const _photoBucket = 'repair-request-photos';

  final SupabaseClient _supabase;

  Future<bool> submit(RepairRequest request, List<XFile> photos) async {
    final requesterId = _supabase.auth.currentUser?.id;
    if (requesterId == null) {
      debugPrint('RepairRequestService.submit error: user is not authenticated');
      return false;
    }

    try {
      final photoPaths = await _uploadPhotos(photos);
      // Critical Medical Assistance requests always jump to 'urgent',
      // overriding the type's normal default priority, so they surface
      // above other requests without the admin having to notice the flag.
      final priority = request.isCriticalMedical
          ? 'urgent'
          : RepairRequest.suggestedPriority(request.assistanceType);
      await _supabase.from(_table).insert(
        RepairRequest(
          requesterId: requesterId,
          locationName: request.locationName,
          latitude: request.latitude,
          longitude: request.longitude,
          assistanceType: request.assistanceType,
          damageDescription: request.damageDescription,
          contactNumber: request.contactNumber,
          photoPaths: photoPaths,
          priority: priority,
          details: request.details,
        ).toJson(),
      );
      return true;
    } catch (error) {
      debugPrint('RepairRequestService.submit error: $error');
      return false;
    }
  }

  Future<List<String>> _uploadPhotos(List<XFile> photos) async {
    final uploadBatch = DateTime.now().microsecondsSinceEpoch.toString();
    final uploaderId = _supabase.auth.currentUser?.id;
    if (uploaderId == null) {
      throw StateError('A signed-in user is required to upload repair request photos.');
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

  Future<String> getSignedPhotoUrl(String path, {int expiresInSeconds = 3600}) {
    return _supabase.storage.from(_photoBucket).createSignedUrl(path, expiresInSeconds);
  }

  Future<List<RepairRequest>> getUserRequests(String requesterId) async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('requester_id', requesterId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => RepairRequest.fromJson(e)).toList();
  }

  Future<RepairRequest?> getRequestById(String requestId) async {
    final data = await _supabase.from(_table).select().eq('id', requestId).maybeSingle();
    return data == null ? null : RepairRequest.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getAllRequestsWithAccountInfo() async {
    final data = await _supabase
        .from(_table)
        .select('*, account:requester_id(name, email)')
        .order('priority', ascending: false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<RepairRequest>> getHelperTasks(String helperId) async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('assigned_helper_id', helperId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => RepairRequest.fromJson(e)).toList();
  }

  Future<void> updateFields(String requestId, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _supabase.from(_table).update(updates).eq('id', requestId);
  }
}