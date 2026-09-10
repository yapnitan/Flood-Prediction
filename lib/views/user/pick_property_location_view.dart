import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/map_config.dart';
import '../../services/location_service.dart';

class PickedLocation {
  const PickedLocation({required this.point, this.geocode});

  final LatLng point;
  final GeocodeResult? geocode;
}

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

  GeocodeResult? _geocode;
  bool _isResolving = false;
  Future<GeocodeResult?>? _areaFuture;
  int _pickSeq = 0;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
    if (_picked != null) _resolveArea(_picked!);
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() => _picked = point);
    _resolveArea(point);
  }

  void _resolveArea(LatLng point) {
    final seq = ++_pickSeq;
    setState(() {
      _geocode = null;
      _isResolving = true;
    });
    final future = _locationService.reverseGeocode(point.latitude, point.longitude);
    _areaFuture = future;
    future.then((result) {
      if (!mounted || seq != _pickSeq) return;
      setState(() {
        _geocode = result;
        _isResolving = false;
      });
    });
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
    _resolveArea(here);
  }

  Future<void> _confirm() async {
    final point = _picked;
    if (point == null) return;
    var geocode = _geocode;
    if (geocode == null && _isResolving) {
      geocode = await _areaFuture;
    }
    if (!mounted) return;
    Navigator.pop(context, PickedLocation(point: point, geocode: geocode));
  }

  String _areaLine() {
    if (_isResolving) return 'Finding area…';
    final g = _geocode;
    if (g == null) return 'Area could not be detected — coordinates still saved';
    final parts = [
      if ((g.district ?? '').trim().isNotEmpty) g.district!.trim(),
      if ((g.state ?? '').trim().isNotEmpty) g.state!.trim(),
    ];
    return parts.isEmpty ? (g.address ?? 'Area could not be detected') : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
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
              cameraConstraint: kMalaysiaCameraConstraint,
              interactionOptions: kMapInteractionOptions,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _picked == null
                        ? 'Tap on the map to place a marker'
                        : '${_picked!.latitude.toStringAsFixed(6)}, '
                            '${_picked!.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if (_picked != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (_isResolving) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else
                          const Icon(Icons.place_outlined, size: 13, color: Colors.white70),
                        if (!_isResolving) const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _areaLine(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
