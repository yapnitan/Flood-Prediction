import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../constants/map_config.dart';

class MapMarkerSpec {
  const MapMarkerSpec({
    required this.point,
    required this.color,
    this.icon = Icons.location_on,
    this.label,
    this.onTap,
  });

  final LatLng point;
  final Color color;
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
}

/// shows where a request/facility is compared to everything else
/// interactive: false — small fixed-height preview, pan/zoom disabled, used by user/helper
/// interactive: true — pan/zoom/tap enabled, used by the admin
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.markers,
    this.interactive = false,
    this.height = 180,
    this.borderRadius = 12,
  });

  final List<MapMarkerSpec> markers;
  final bool interactive;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();

    final points = markers.map((m) => m.point).toList();
    final options = MapOptions(
      initialCenter: points.first,
      initialZoom: 15,
      initialCameraFit: points.length > 1
          ? CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(40),
              maxZoom: 16,
            )
          : null,
      interactionOptions: InteractionOptions(
        flags: interactive ? kMapInteractionFlags : InteractiveFlag.none,
      ),
      cameraConstraint: interactive ? kMalaysiaCameraConstraint : const CameraConstraint.unconstrained(),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: options,
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.flood_prediction',
                ),
                MarkerLayer(
                  markers: markers
                      .map(
                        (m) => Marker(
                          point: m.point,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: m.onTap,
                            child: Icon(m.icon, color: m.color, size: 34, shadows: const [
                              Shadow(color: Colors.black38, blurRadius: 3),
                            ]),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const Positioned(
              right: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xB3FFFFFF),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 8, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
