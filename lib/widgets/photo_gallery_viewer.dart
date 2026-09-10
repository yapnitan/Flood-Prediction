import 'package:flutter/material.dart';

class PhotoGalleryViewer extends StatelessWidget {
  const PhotoGalleryViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (context, index) => InteractiveViewer(
          child: Center(child: Image.network(urls[index], fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
