import 'package:flutter/material.dart';

/// Thumbnail for an already-uploaded photo, resolved from a storage path to
/// a signed URL via [urlResolver] (whichever feature's service owns that
/// bucket — repair requests, flood reports, asset loss reports, ...).
/// Distinct from [PhotoPreview], which only handles local XFile picker
/// images pre-upload.
class NetworkPhotoThumbnail extends StatelessWidget {
  const NetworkPhotoThumbnail({
    super.key,
    required this.storagePath,
    required this.urlResolver,
    this.onTap,
  });

  final String storagePath;
  final Future<String> Function(String path) urlResolver;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: urlResolver(storagePath),
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
