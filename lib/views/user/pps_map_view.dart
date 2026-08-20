import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../controllers/facility_controller.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';
import '../../services/location_service.dart';
import '../../utils/geo_utils.dart';
import '../../utils/maps_launcher.dart';
import '../../utils/responsive.dart';
import '../../widgets/mini_map.dart';

/// "Nearby PPS" + "Navigation to PPS" (CLAUDE.md Task 8) — PPS (Pusat
/// Pemindahan Sementara) are Malaysia's temporary evacuation shelters,
/// modeled here as [Facility] rows with `facilityType == 'shelter'` (see
/// facility.dart). Reuses the same [FacilityController]/[MiniMap]/
/// [openDirections] the repair-request assignment flow already uses,
/// rather than a parallel evacuation-center stack.
class PpsMapView extends StatefulWidget {
  const PpsMapView({super.key});

  @override
  State<PpsMapView> createState() => _PpsMapViewState();
}

class _PpsMapViewState extends State<PpsMapView> {
  final _facilityController = FacilityController(FacilityService());
  final _locationService = LocationService();

  List<Facility> _shelters = [];
  double? _latitude;
  double? _longitude;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shelters = await _facilityController.getAssignableFacilities('shelter');
    final Position? position = await _locationService.getCurrentPosition();
    if (!mounted) return;

    final lat = position?.latitude;
    final lon = position?.longitude;

    if (lat != null && lon != null) {
      shelters.sort((a, b) {
        final da = haversineDistanceKm(lat1: lat, lon1: lon, lat2: a.latitude, lon2: a.longitude);
        final db = haversineDistanceKm(lat1: lat, lon1: lon, lat2: b.latitude, lon2: b.longitude);
        return da.compareTo(db);
      });
    }

    setState(() {
      _shelters = shelters;
      _latitude = lat;
      _longitude = lon;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final markers = <MapMarkerSpec>[
      if (_latitude != null && _longitude != null)
        MapMarkerSpec(
          point: LatLng(_latitude!, _longitude!),
          color: Colors.blue,
          icon: Icons.my_location,
        ),
      for (final shelter in _shelters)
        MapMarkerSpec(
          point: LatLng(shelter.latitude, shelter.longitude),
          color: Colors.green,
          icon: Icons.night_shelter,
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Nearby Evacuation Centers')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: markers.isEmpty
                            ? const Center(child: Text('No evacuation centers available yet.'))
                            : Padding(
                                padding: const EdgeInsets.all(16),
                                child: LayoutBuilder(
                                  builder: (context, constraints) => MiniMap(
                                    markers: markers,
                                    interactive: true,
                                    height: constraints.maxHeight,
                                  ),
                                ),
                              ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _shelters.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: _shelters.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final shelter = _shelters[index];
                                  final distanceKm = (_latitude != null && _longitude != null)
                                      ? haversineDistanceKm(
                                          lat1: _latitude!,
                                          lon1: _longitude!,
                                          lat2: shelter.latitude,
                                          lon2: shelter.longitude,
                                        )
                                      : null;
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.night_shelter, color: Colors.green),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(shelter.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              if (distanceKm != null)
                                                Text(
                                                  '${distanceKm.toStringAsFixed(1)} km away'
                                                  '${shelter.capacity != null ? ' · capacity ${shelter.capacity}' : ''}',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                )
                                              else if (shelter.address != null)
                                                Text(
                                                  shelter.address!,
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                            ],
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => openDirections(
                                            context,
                                            latitude: shelter.latitude,
                                            longitude: shelter.longitude,
                                          ),
                                          icon: const Icon(Icons.directions, size: 18),
                                          label: const Text('Directions'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
