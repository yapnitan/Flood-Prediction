import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/area_risk_controller.dart';
import '../controllers/environment_controller.dart';
import '../controllers/flood_report_controller.dart';
import '../controllers/historical_flood_controller.dart';
import '../models/facility.dart';
import '../models/flood_report.dart';
import '../services/area_risk_service.dart';
import '../services/facility_service.dart';
import '../services/flood_report_service.dart';
import '../services/historical_flood_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_alert_service.dart';
import '../services/terrain_service.dart';
import '../services/weather_service.dart';
import '../utils/geo_utils.dart';
import '../utils/maps_launcher.dart';
import 'info_box.dart';
import 'photo_gallery_viewer.dart';

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
  final _facilityService = FacilityService();
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

  List<Facility> _evacuationCenters = const [];
  bool _isLoadingEvacuationCenters = true;

  AreaRiskResult? _areaRisk;
  double? _rainfallMm;
  List<FloodReport> _nearbyReports = const [];
  bool _isLoadingAreaRisk = true;

  /// Task 12 "weather warnings" — notifies once when rainfall crosses this
  /// threshold, not on every refresh while it stays high.
  static const double _heavyRainfallThresholdMm = 20;
  bool _heavyRainfallWarned = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    RealtimeAlertService.instance.stopFloodReportWatch();
    super.dispose();
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
    unawaited(_loadEvacuationCenters());
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

  /// Evacuation center markers are fetched independently of flood reports
  /// (separate service, separate loading flag) so a slow/failed shelter
  /// lookup never blocks the flood report markers from appearing, and
  /// vice versa.
  Future<void> _loadEvacuationCenters() async {
    final centers = await _facilityService.getFacilitiesByType('shelter');
    if (!mounted) return;
    setState(() {
      _evacuationCenters = centers;
      _isLoadingEvacuationCenters = false;
    });
  }

  Future<void> _loadAreaRisk(Position? position) async {
    if (position == null) {
      if (mounted) setState(() => _isLoadingAreaRisk = false);
      return;
    }

    // Task 12 "nearby flood reports" — arms a session-based Realtime watch
    // around the user's current location once it's known.
    RealtimeAlertService.instance.watchNearbyFloodReports(
      latitude: position.latitude,
      longitude: position.longitude,
    );

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

    _checkWeatherWarning(assessment.currentRainfallMm);
  }

  void _checkWeatherWarning(double? rainfallMm) {
    final isHeavy = rainfallMm != null && rainfallMm >= _heavyRainfallThresholdMm;
    if (isHeavy && !_heavyRainfallWarned) {
      _heavyRainfallWarned = true;
      NotificationService.instance.showNow(
        id: NotificationService.idWeatherWarning,
        title: 'Heavy rainfall warning',
        body: '${rainfallMm.toStringAsFixed(1)}mm of rain recorded near your current location.',
      );
    } else if (!isHeavy) {
      _heavyRainfallWarned = false;
    }
  }

  /// Re-fetches report markers and recomputes the area risk badge, reusing
  /// the already-known GPS position rather than requesting a fresh one.
  /// Called by [UserHome] via a [GlobalKey] after a new report is
  /// submitted, since this widget stays alive inside the Home tab's
  /// `IndexedStack` rather than being recreated.
  Future<void> refresh() async {
    setState(() => _isLoadingAreaRisk = true);
    await Future.wait([
      _loadMap(_position),
      _loadAreaRisk(_position),
      _loadEvacuationCenters(),
    ]);
  }

  /// Unlike [refresh], re-runs the full GPS acquisition (including the
  /// permission check/request) instead of reusing [_position]. Called by
  /// [UserHome]'s pull-to-refresh so a user who previously denied location
  /// access gets prompted again; if it's granted this time, location-based
  /// content updates, and if denied again the page keeps working off the
  /// fallback center.
  Future<void> refreshLocation() async {
    setState(() {
      _isLoadingMap = true;
      _isLoadingAreaRisk = true;
      _isLoadingEvacuationCenters = true;
      _statusMessage = null;
    });
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    _position = position;
    await Future.wait([
      _loadMap(position),
      _loadAreaRisk(position),
      _loadEvacuationCenters(),
    ]);
  }

  /// The closest fetched evacuation center to the user's current position,
  /// or `null` if the position or the center list isn't available yet.
  Facility? get _nearestEvacuationCenter {
    final location = _currentLocation;
    if (location == null || _evacuationCenters.isEmpty) return null;

    Facility? nearest;
    double? nearestDistanceKm;
    for (final center in _evacuationCenters) {
      final distanceKm = haversineDistanceKm(
        lat1: location.latitude,
        lon1: location.longitude,
        lat2: center.latitude,
        lon2: center.longitude,
      );
      if (nearestDistanceKm == null || distanceKm < nearestDistanceKm) {
        nearest = center;
        nearestDistanceKm = distanceKm;
      }
    }
    return nearest;
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
                Icon(
                  _areaRiskIcon(risk.level),
                  color: _areaRiskColor(risk.level),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${risk.level} flood risk right now',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  '${risk.score.toStringAsFixed(0)}/100',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
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
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
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
            if (report.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: FutureBuilder<List<String>>(
                  future: _floodReportService.getPhotoUrls(report.photoPaths),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final urls = snapshot.data ?? [];
                    if (urls.isEmpty) {
                      return Text(
                        'Photos unavailable',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      );
                    }
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: urls.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => _openPhotoViewer(urls, index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            urls[index],
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEvacuationCenterInfo(Facility center) {
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
                const Icon(Icons.night_shelter, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    center.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (center.address != null) ...[
              Text(center.address!),
              const SizedBox(height: 4),
            ],
            if (center.capacity != null) ...[
              Text('Capacity: ${center.capacity}'),
              const SizedBox(height: 4),
            ],
            if (center.contactNumber != null)
              Text('Contact: ${center.contactNumber}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => openDirections(
                  context,
                  latitude: center.latitude,
                  longitude: center.longitude,
                ),
                icon: const Icon(Icons.directions),
                label: const Text('View route'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            PhotoGalleryViewer(urls: urls, initialIndex: initialIndex),
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
          onTap: _areaRisk == null
              ? null
              : () => _showAreaRiskDetail(_areaRisk!),
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
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.flood_prediction',
                      ),
                      // Task 13 "heatmap" — flutter_map_heatmap has no
                      // release compatible with flutter_map 8.x (its latest
                      // pins flutter_map <8.0.0), so density is approximated
                      // with flutter_map's own CircleLayer instead: one
                      // translucent, severity-colored circle per report,
                      // overlapping circles in a dense area visually "add up"
                      // into a hotter patch without an extra dependency.
                      CircleLayer(
                        circles: _reports
                            .map(
                              (report) => CircleMarker(
                                point: LatLng(report.latitude, report.longitude),
                                radius: _reportHeatRadius(report.waterLevel),
                                useRadiusInMeter: true,
                                color: _areaRiskColor(report.waterLevel).withValues(alpha: 0.18),
                                borderStrokeWidth: 0,
                              ),
                            )
                            .toList(),
                      ),
                      // Reports are clustered — a busy area can have many
                      // overlapping pins at low zoom, so group them into a
                      // count bubble that expands as the user zooms in.
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 45,
                          size: const Size(36, 36),
                          markers: _reports
                              .map(
                                (report) => Marker(
                                  point: LatLng(report.latitude, report.longitude),
                                  width: 36,
                                  height: 36,
                                  child: GestureDetector(
                                    onTap: () => _showReportInfo(report),
                                    child: Icon(
                                      Icons.location_on,
                                      color: _areaRiskColor(report.waterLevel),
                                      size: 32,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          builder: (context, markers) => Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${markers.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
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
                          ..._evacuationCenters.map(
                            (center) => Marker(
                              point: LatLng(center.latitude, center.longitude),
                              width: 36,
                              height: 36,
                              child: GestureDetector(
                                onTap: () => _showEvacuationCenterInfo(center),
                                child: const Icon(
                                  Icons.night_shelter,
                                  color: Colors.green,
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
                if (!_isLoadingMap && _isLoadingEvacuationCenters)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ---- Rainfall / Water level / Nearby reports ----
        // Wrapped in IntrinsicHeight + stretch so all three cards match the
        // height of whichever has the most content (e.g. "No reports
        // nearby" wraps to two lines while "3.2 mm" doesn't).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ),

        const SizedBox(height: 20),

        // ---- Route to nearest evacuation center ----
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _nearestEvacuationCenter == null
                ? null
                : () => openDirections(
                    context,
                    latitude: _nearestEvacuationCenter!.latitude,
                    longitude: _nearestEvacuationCenter!.longitude,
                  ),
            icon: const Icon(Icons.directions),
            label: const Text('View Route to Nearest Evacuation Center'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
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
                  : Icon(
                      _areaRiskIcon(level),
                      size: 48,
                      color: _areaRiskColor(level),
                    ),
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
                      areaRisk != null
                          ? '${areaRisk!.level} risk'
                          : 'Unavailable',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _areaRiskColor(level),
                      ),
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

/// Approximate "heat" radius (meters) for a report's density circle —
/// higher water level reads as a wider hazard footprint.
double _reportHeatRadius(String waterLevel) {
  switch (waterLevel) {
    case 'High':
      return 250;
    case 'Medium':
      return 150;
    default:
      return 80;
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
