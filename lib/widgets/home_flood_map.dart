import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';

/// Stand-in for real community flood reports until the Community Reporting
/// module (owned separately, has its own `flood_report` table/service) is
/// built and wired up here. Remove this data + the markers using it once
/// that's in place.
class _PlaceholderReport {
  final LatLng position;
  final String location;
  final String waterLevel;
  final String reportedAgo;

  const _PlaceholderReport({
    required this.position,
    required this.location,
    required this.waterLevel,
    required this.reportedAgo,
  });
}

const _placeholderReports = [
  _PlaceholderReport(
    position: LatLng(3.1478, 101.6953),
    location: 'Jalan Tun Razak, Kuala Lumpur',
    waterLevel: 'Medium (10-30cm)',
    reportedAgo: '25 min ago',
  ),
  _PlaceholderReport(
    position: LatLng(3.0738, 101.5183),
    location: 'Kuala Langat, Selangor',
    waterLevel: 'High (>30cm)',
    reportedAgo: '1 hr ago',
  ),
  _PlaceholderReport(
    position: LatLng(3.2078, 101.6415),
    location: 'Gombak, Selangor',
    waterLevel: 'Low (<10cm)',
    reportedAgo: '3 hr ago',
  ),
];

/// Home-tab map: current location + nearby flood reports (placeholder data
/// for now — see [_placeholderReports]). Uses OpenStreetMap tiles via
/// flutter_map, no API key required.
class HomeFloodMap extends StatefulWidget {
  const HomeFloodMap({super.key});

  @override
  State<HomeFloodMap> createState() => _HomeFloodMapState();
}

class _HomeFloodMapState extends State<HomeFloodMap> {
  static const _fallbackCenter = LatLng(3.1390, 101.6869); // Kuala Lumpur

  final _locationService = LocationService();
  final _mapController = MapController();

  LatLng? _currentLocation;
  bool _isLoading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (position != null) {
        _currentLocation = LatLng(position.latitude, position.longitude);
      } else {
        _statusMessage = 'Location unavailable — showing default area';
      }
    });
  }

  void _showReportInfo(_PlaceholderReport report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.location,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Water level: ${report.waterLevel}'),
            const SizedBox(height: 4),
            Text(
              'Reported ${report.reportedAgo}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sample data — community reporting is still in progress.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentLocation ?? _fallbackCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 260,
        child: Stack(
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.flood_prediction',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_currentLocation != null)
                        Marker(
                          point: _currentLocation!,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                      ..._placeholderReports.map(
                        (report) => Marker(
                          point: report.position,
                          width: 36,
                          height: 36,
                          child: GestureDetector(
                            onTap: () => _showReportInfo(report),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            if (_statusMessage != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
