import 'package:flutter/material.dart';

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

  static const _brokenImage = ColoredBox(
    color: Color(0xFFF2F2F2),
    child: Icon(Icons.broken_image_outlined, color: Colors.grey),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: urlResolver(storagePath),
      builder: (context, snapshot) {
        final Widget child;
        if (snapshot.hasError) {
          child = _brokenImage;
        } else if (snapshot.hasData) {
          child = Image.network(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _brokenImage,
          );
        } else {
          child = const ColoredBox(
            color: Color(0xFFF2F2F2),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(onTap: onTap, child: child),
        );
      },
    );
  }
}
