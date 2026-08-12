import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';

/// Full-screen map for picking a property's location: tap anywhere to drop
/// (or move) a marker, or use the FAB to center on the device's current
/// GPS position. Pops [LatLng] on confirm, or null if the user backs out
/// without picking anything.
class PickPropertyLocationView extends StatefulWidget {
  const PickPropertyLocationView({super.key, this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<PickPropertyLocationView> createState() => _PickPropertyLocationViewState();
}

class _PickPropertyLocationViewState extends State<PickPropertyLocationView> {
  static const _fallbackCenter = LatLng(3.1390, 101.6869); // Kuala Lumpur

  final _mapController = MapController();
  final _locationService = LocationService();

  LatLng? _picked;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() => _picked = point);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _isLocating = false);

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location')),
      );
      return;
    }

    final here = LatLng(position.latitude, position.longitude);
    setState(() => _picked = here);
    _mapController.move(here, 16);
  }

  void _confirm() {
    if (_picked == null) return;
    Navigator.pop(context, _picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Property Location'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _picked == null ? null : _confirm,
            child: const Text('Confirm'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _picked ?? _fallbackCenter,
              initialZoom: _picked != null ? 15 : 12,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flood_prediction',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _picked == null
                    ? 'Tap on the map to place a marker at your property'
                    : '${_picked!.latitude.toStringAsFixed(6)}, '
                        '${_picked!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLocating ? null : _useCurrentLocation,
        icon: _isLocating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.my_location),
        label: const Text('Use current location'),
      ),
    );
  }
}
