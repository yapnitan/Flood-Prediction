import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/flood_report.dart';
import '../services/flood_report_service.dart';
import '../services/location_service.dart';

/// Home-tab map: current location + nearby community flood reports, read
/// live from Supabase's `flood_report` table via [FloodReportService].
/// Uses OpenStreetMap tiles via flutter_map, no API key required.
class HomeFloodMap extends StatefulWidget {
  /// Optional GPS fix shared with the parent (e.g. [UserHome]'s "flood
  /// status" badge), which needs the same coordinate. Two independent
  /// `Geolocator.getCurrentPosition()` calls fired at once from the same
  /// screen can cause one of them to time out on Android, so callers that
  /// already need a position elsewhere on the page should fetch it once
  /// and pass it down here rather than letting this widget fetch its own.
  final Future<Position?>? positionFuture;

  const HomeFloodMap({super.key, this.positionFuture});

  @override
  State<HomeFloodMap> createState() => HomeFloodMapState();
}

class HomeFloodMapState extends State<HomeFloodMap> {
  static const _fallbackCenter = LatLng(3.1390, 101.6869); // Kuala Lumpur

  final _locationService = LocationService();
  final _floodReportService = FloodReportService();
  final _mapController = MapController();

  LatLng? _currentLocation;
  List<FloodReport> _reports = const [];
  bool _isLoading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Re-fetches just the report markers, leaving the current map position
  /// alone. Called by [UserHome] via a [GlobalKey] after a new report is
  /// submitted, since this widget stays alive (and its state is preserved)
  /// inside the home tab's [IndexedStack] rather than being recreated.
  Future<void> refresh() async {
    final reports = await _floodReportService.getRecent();
    if (!mounted) return;
    setState(() => _reports = reports);
  }

  Future<void> _loadData() async {
    final positionFuture =
        widget.positionFuture ?? _locationService.getCurrentPosition();
    final reportsFuture = _floodReportService.getRecent();

    final position = await positionFuture;
    final reports = await reportsFuture;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _reports = reports;
      if (position != null) {
        _currentLocation = LatLng(position.latitude, position.longitude);
      } else {
        _statusMessage = 'Location unavailable — showing default area';
      }
    });
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  void _showReportInfo(FloodReport report) {
    final reportedTime = report.createdAt ?? report.observedAt;
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
                    report.locationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Flood type: ${report.floodType}'),
            const SizedBox(height: 4),
            Text('Water level: ${report.waterLevel}'),
            const SizedBox(height: 4),
            Text(report.description),
            const SizedBox(height: 4),
            Text(
              'Reported ${_formatTimeAgo(reportedTime)}',
              style: TextStyle(color: Colors.grey[600]),
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
                      ..._reports.map(
                        (report) => Marker(
                          point: LatLng(report.latitude, report.longitude),
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
