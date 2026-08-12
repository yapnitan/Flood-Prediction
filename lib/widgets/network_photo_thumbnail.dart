import 'package:flutter/material.dart';
import '../services/repair_request_service.dart';

/// Thumbnail for an already-uploaded repair_request photo, resolved from
/// a storage path to a signed URL. Distinct from [PhotoPreview], which
/// only handles local XFile picker images pre-upload.
class NetworkPhotoThumbnail extends StatelessWidget {
  const NetworkPhotoThumbnail({
    super.key,
    required this.storagePath,
    required this.repairRequestService,
    this.onTap,
  });

  final String storagePath;
  final RepairRequestService repairRequestService;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: repairRequestService.getSignedPhotoUrl(storagePath),
      builder: (context, snapshot) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: onTap,
            child: snapshot.hasData
                ? Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: Color(0xFFF2F2F2),
                child: Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
            )
                : const ColoredBox(
              color: Color(0xFFF2F2F2),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}