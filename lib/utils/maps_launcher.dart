import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a Google Maps turn-by-turn directions request for [latitude]/
/// [longitude]. Used by the helper (and admin) views so getting to a
/// request's location doesn't mean copying raw coordinates by hand.
Future<void> openDirections(
  BuildContext context, {
  required double latitude,
  required double longitude,
}) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
  );

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps.')),
    );
  }
}
