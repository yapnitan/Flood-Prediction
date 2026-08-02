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
      await _supabase
          .from(_table)
          .insert(
            RepairRequest(
              requesterId: requesterId,
              locationName: request.locationName,
              latitude: request.latitude,
              longitude: request.longitude,
              assistanceType: request.assistanceType,
              damageDescription: request.damageDescription,
              contactNumber: request.contactNumber,
              photoPaths: photoPaths,
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
}
