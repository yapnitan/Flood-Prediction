import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/area_risk_controller.dart';
import '../controllers/environment_controller.dart';
import '../controllers/flood_report_controller.dart';
import '../controllers/historical_flood_controller.dart';
import '../models/flood_report.dart';
import '../services/area_risk_service.dart';
import '../services/flood_report_service.dart';
import '../services/historical_flood_service.dart';
import '../services/location_service.dart';
import '../services/terrain_service.dart';
import '../services/weather_service.dart';
import 'info_box.dart';

/// Home tab's "what's the flood situation right now" block: the combined
/// flood-status badge (historical baseline + live rainfall + nearby
/// community reports, see [AreaRiskController]) together with the live map
/// of the current location and nearby community flood reports.
///
/// These were originally two separate widgets that each fetched GPS
/// position independently. On a real device, two concurrent
/// `Geolocator.getCurrentPosition()` calls fired from the same screen
/// aren't reliably serviced in parallel — one silently times out. Merging
/// them into a single widget means there's only ever one GPS call shared
/// by both the badge and the map.
class HomeFloodOverview extends StatefulWidget {
  const HomeFloodOverview({super.key});

  @override
  State<HomeFloodOverview> createState() => HomeFloodOverviewState();
}

class HomeFloodOverviewState extends State<HomeFloodOverview> {
  static const _fallbackCenter = LatLng(3.1390, 101.6869); // Kuala Lumpur

  final _locationService = LocationService();
  final _floodReportService = FloodReportService();
  final _areaRiskController = AreaRiskController(
    HistoricalFloodController(HistoricalFloodService()),
    EnvironmentController(TerrainService(), WeatherService()),
    FloodReportController(FloodReportService()),
    AreaRiskService(),
  );
  final _mapController = MapController();

  Position? _position;
  LatLng? _currentLocation;
  List<FloodReport> _reports = const [];
  bool _isLoadingMap = true;
  String? _statusMessage;

  AreaRiskResult? _areaRisk;
  double? _rainfallMm;
  List<FloodReport> _nearbyReports = const [];
  bool _isLoadingAreaRisk = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final position = await _locationService.getCurrentPosition();
    _position = position;
    if (!mounted) return;

    // Loaded independently so the map (which doesn't wait on weather/
    // historical/report lookups) can appear before the slower badge does,
    // rather than both waiting on whichever input is slowest.
    unawaited(_loadMap(position));
    unawaited(_loadAreaRisk(position));
  }

  Future<void> _loadMap(Position? position) async {
    final reports = await _floodReportService.getRecent();
    if (!mounted) return;
    setState(() {
      _isLoadingMap = false;
      _reports = reports;
      if (position != null) {
        _currentLocation = LatLng(position.latitude, position.longitude);
      } else {
        _statusMessage = 'Location unavailable — showing default area';
      }
    });
  }

  Future<void> _loadAreaRisk(Position? position) async {
    if (position == null) {
      if (mounted) setState(() => _isLoadingAreaRisk = false);
      return;
    }
    final assessment = await _areaRiskController.assessCurrentLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (!mounted) return;
    setState(() {
      _areaRisk = assessment.result;
      _rainfallMm = assessment.currentRainfallMm;
      _nearbyReports = assessment.nearbyReports;
      _isLoadingAreaRisk = false;
    });
  }

  /// Re-fetches report markers and recomputes the area risk badge, reusing
  /// the already-known GPS position rather than requesting a fresh one.
  /// Called by [UserHome] via a [GlobalKey] after a new report is
  /// submitted, since this widget stays alive inside the Home tab's
  /// `IndexedStack` rather than being recreated.
  Future<void> refresh() async {
    setState(() => _isLoadingAreaRisk = true);
    await Future.wait([_loadMap(_position), _loadAreaRisk(_position)]);
  }

  void _showAreaRiskDetail(AreaRiskResult risk) {
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
                Icon(_areaRiskIcon(risk.level), color: _areaRiskColor(risk.level)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${risk.level} flood risk right now',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  '${risk.score.toStringAsFixed(0)}/100',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final factor in risk.factors)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            factor.factorName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            factor.factorValue,
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${factor.scoreContribution.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'This combines nearby historical flood records with live rainfall '
              'and recent community reports near your current location — it\'s '
              'a general area indicator, not a substitute for running a full '
              'property risk assessment.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Flood status + alert icon, combined into one card ----
        _FloodRiskCard(
          areaRisk: _areaRisk,
          isLoading: _isLoadingAreaRisk,
          onTap: _areaRisk == null ? null : () => _showAreaRiskDetail(_areaRisk!),
        ),

        const SizedBox(height: 20),

        // ---- Current location + nearby flood reports ----
        const Text(
          "Current location",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                if (_isLoadingMap)
                  const Center(child: CircularProgressIndicator())
                else
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation ?? _fallbackCenter,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                      ),
                    ],
                  ),
                if (_statusMessage != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        ),

        const SizedBox(height: 20),

        // ---- Rainfall / Water level / Nearby reports ----
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: "Rainfall",
                isLoading: _isLoadingAreaRisk,
                value: _rainfallMm != null
                    ? '${_rainfallMm!.toStringAsFixed(1)} mm'
                    : 'Unavailable',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: "Water level",
                isLoading: _isLoadingAreaRisk,
                value: _nearbyReports.isEmpty
                    ? 'No reports nearby'
                    : _nearbyReports.first.waterLevel,
                valueColor: _nearbyReports.isEmpty
                    ? null
                    : _areaRiskColor(_nearbyReports.first.waterLevel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: "Nearby reports",
                isLoading: _isLoadingAreaRisk,
                value: '${_nearbyReports.length}',
                caption: 'within 5km, 24h',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The "Flood Risk" text and its alert icon used to be two separate
/// [InfoBox] tiles side by side; combined here into a single card so the
/// icon reads as part of the same statement rather than a disconnected
/// second box.
class _FloodRiskCard extends StatelessWidget {
  final AreaRiskResult? areaRisk;
  final bool isLoading;
  final VoidCallback? onTap;

  const _FloodRiskCard({
    required this.areaRisk,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final level = areaRisk?.level;
    return InfoBox(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Icon(_areaRiskIcon(level), size: 48, color: _areaRiskColor(level)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Flood Risk",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  if (isLoading)
                    Text(
                      'Checking current conditions…',
                      style: TextStyle(color: Colors.grey[600]),
                    )
                  else
                    Text(
                      areaRisk != null ? '${areaRisk!.level} risk' : 'Unavailable',
                      style: TextStyle(fontWeight: FontWeight.bold, color: _areaRiskColor(level)),
                    ),
                  if (areaRisk != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Tap for details',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _areaRiskIcon(String? level) {
  switch (level) {
    case 'High':
      return Icons.dangerous;
    case 'Medium':
      return Icons.warning_amber_rounded;
    case 'Low':
      return Icons.check_circle;
    default:
      return Icons.help_outline;
  }
}

Color _areaRiskColor(String? level) {
  switch (level) {
    case 'High':
      return Colors.red;
    case 'Medium':
      return Colors.orange;
    case 'Low':
      return Colors.green;
    default:
      return Colors.grey;
  }
}

/// Small labelled stat tile — rainfall, nearest report's water level,
/// nearby report count — sharing the same [InfoBox] card style as
/// [_FloodRiskCard].
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isLoading;
  final Color? valueColor;
  final String? caption;

  const _StatBox({
    required this.label,
    required this.value,
    required this.isLoading,
    this.valueColor,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return InfoBox(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          if (isLoading)
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
            ),
          if (!isLoading && caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}
