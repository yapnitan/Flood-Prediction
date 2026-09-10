import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPreview extends StatelessWidget {
  const PhotoPreview({super.key, required this.photo, required this.onRemove});

  final XFile photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: photo.readAsBytes(),
      builder: (context, snapshot) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: snapshot.hasData
                  ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                  : const ColoredBox(
                      color: Color(0xFFF2F2F2),
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Remove photo',
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        );
      },
    );
  }
}
