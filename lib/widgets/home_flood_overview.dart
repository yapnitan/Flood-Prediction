import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../constants/map_config.dart';
import '../controllers/area_risk_controller.dart';
import '../controllers/environment_controller.dart';
import '../controllers/flood_report_controller.dart';
import '../controllers/historical_flood_controller.dart';
import '../models/facility.dart';
import '../models/flood_report.dart';
import '../models/historical_flood.dart';
import '../models/infobanjir_station.dart';
import '../models/river_flood_data.dart';
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
  InfoBanjirStation? _rainfallStation;
  InfoBanjirStation? _riverStation;
  List<FloodReport> _nearbyReports = const [];
  List<HistoricalFlood> _nearbyHistoricalFloods = const [];
  RiverFloodData? _riverFlood;
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
      _rainfallStation = assessment.rainfallStation;
      _riverStation = assessment.riverStation;
      _nearbyReports = assessment.nearbyReports;
      _nearbyHistoricalFloods = assessment.nearbyHistoricalFloods;
      _riverFlood = assessment.riverFlood;
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

  /// The nearby reports' water levels averaged into a single category:
  /// Low/Medium/High are scored 1/2/3, averaged, then rounded back to the
  /// nearest category. Null when there are no nearby reports.
  static const _waterLevelRank = {'Low': 1, 'Medium': 2, 'High': 3};
  static const _waterLevelLabels = ['Low', 'Medium', 'High'];

  String? get _averageWaterLevel {
    if (_nearbyReports.isEmpty) return null;
    final scores = _nearbyReports
        .map((r) => _waterLevelRank[r.waterLevel])
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return _nearbyReports.first.waterLevel;
    final average = scores.reduce((a, b) => a + b) / scores.length;
    return _waterLevelLabels[average.round().clamp(1, 3) - 1];
  }

  static const _factorMaxPoints = <String, double>{
    'Historical flood frequency (20km)': 25,
    'Current rainfall': 25,
    'Community reports nearby (5km, 24h)': 30,
    'Nearby river level': 20,
  };

  static const _factorHowScored = <String, String>{
    'Historical flood frequency (20km)':
        '+5 points for every JPS/DID recorded flood within 20 km of you, up to 25.',
    'Current rainfall':
        "Rain in the last hour, using JPS's own bands: Light +10, Moderate "
        '(10–30 mm) +18, Heavy (30 mm+) +25.',
    'Community reports nearby (5km, 24h)':
        '+10 (Low) / +15 (Medium) / +20 (High) per report within 5 km in the '
        'last 24 h, up to 30.',
    'Nearby river level':
        'Nearest JPS/DID river gauge status: Danger +20, Warning +15, Alert +8, '
        'normal-but-rising +3. Falls back to the GloFAS forecast (+8 / +15) '
        'when no gauge is in range.',
  };

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _historicalFactorDetail() {
    if (_nearbyHistoricalFloods.isEmpty) {
      return const Text(
        'No floods on record within 20 km in the JPS/DID dataset.',
        style: TextStyle(fontSize: 12),
      );
    }
    final sorted = [..._nearbyHistoricalFloods]
      ..sort((a, b) => b.floodDate.compareTo(a.floodDate));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in sorted.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              '• ${_formatDate(f.floodDate)} — ${f.floodCause} (${f.district})',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (sorted.length > 8)
          Text(
            '+ ${sorted.length - 8} more',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
      ],
    );
  }

  Widget _rainfallFactorDetail() {
    final station = _rainfallStation;
    if (station == null) {
      final mm = _rainfallMm;
      return Text(
        mm == null
            ? 'No rainfall data available right now.'
            : 'No JPS/DID gauge with a fresh reading within 30 km — showing the '
                  'Open-Meteo forecast model estimate (${mm.toStringAsFixed(1)} mm).',
        style: const TextStyle(fontSize: 12),
      );
    }
    final loc = _currentLocation;
    final distanceKm = loc == null
        ? null
        : haversineDistanceKm(
            lat1: loc.latitude,
            lon1: loc.longitude,
            lat2: station.latitude,
            lon2: station.longitude,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          station.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        if (distanceKm != null)
          Text(
            '${distanceKm.toStringAsFixed(1)} km away'
            '${station.district != null ? ' · ${station.district}' : ''}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        const SizedBox(height: 4),
        if (station.rainfall1hMm != null)
          Text('Last 1 hour: ${station.rainfall1hMm!.toStringAsFixed(1)} mm',
              style: const TextStyle(fontSize: 12)),
        if (station.rainfall3hMm != null)
          Text('Last 3 hours: ${station.rainfall3hMm!.toStringAsFixed(1)} mm',
              style: const TextStyle(fontSize: 12)),
        if (station.rainfallTodayMm != null)
          Text("Today's total: ${station.rainfallTodayMm!.toStringAsFixed(1)} mm",
              style: const TextStyle(fontSize: 12)),
        if ((station.rainfallIntensity ?? '').isNotEmpty)
          Text('Intensity: ${station.rainfallIntensity}',
              style: const TextStyle(fontSize: 12)),
        if (station.rainfallUpdatedAt != null)
          Text('Updated ${_formatTimeAgo(station.rainfallUpdatedAt!)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text('Source: JPS/DID Public InfoBanjir gauge',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _reportsFactorDetail(BuildContext sheetContext) {
    if (_nearbyReports.isEmpty) {
      return const Text(
        'No community flood reports within 5 km in the last 24 hours.',
        style: TextStyle(fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in _nearbyReports.take(6))
          InkWell(
            onTap: () {
              Navigator.pop(sheetContext);
              _showReportInfo(r);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      size: 14, color: _areaRiskColor(r.waterLevel)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${r.floodType} · ${r.waterLevel} water level · '
                      '${_formatTimeAgo(r.createdAt ?? r.observedAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        if (_nearbyReports.length > 6)
          Text('+ ${_nearbyReports.length - 6} more',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _riverFactorDetail() {
    final gauge = _riverStation;
    if (gauge != null) {
      final loc = _currentLocation;
      final distanceKm = loc == null
          ? null
          : haversineDistanceKm(
              lat1: loc.latitude,
              lon1: loc.longitude,
              lat2: gauge.latitude,
              lon2: gauge.longitude,
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gauge.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 12)),
          if (distanceKm != null)
            Text(
              '${distanceKm.toStringAsFixed(1)} km away'
              '${gauge.district != null ? ' · ${gauge.district}' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          const SizedBox(height: 4),
          if (gauge.waterLevelStatus != null)
            Text('Status: ${gauge.waterLevelStatus}',
                style: const TextStyle(fontSize: 12)),
          if (gauge.waterLevelM != null)
            Text(
              'Level: ${gauge.waterLevelM!.toStringAsFixed(2)} m'
              '${gauge.normalLevelM != null ? ' (normal ${gauge.normalLevelM!.toStringAsFixed(2)} m)' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          if (gauge.metresAboveNormal != null && gauge.metresAboveNormal! > 0)
            Text(
              '${gauge.metresAboveNormal!.toStringAsFixed(2)} m above normal',
              style: const TextStyle(fontSize: 12),
            ),
          if (gauge.waterLevelTrend != null)
            Text('Trend: ${gauge.waterLevelTrend}',
                style: const TextStyle(fontSize: 12)),
          if (gauge.waterLevelUpdatedAt != null)
            Text('Updated ${_formatTimeAgo(gauge.waterLevelUpdatedAt!)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('Source: JPS/DID Public InfoBanjir river gauge',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      );
    }

    final rf = _riverFlood;
    if (rf == null || rf.level == RiverFloodLevel.unknown) {
      return const Text(
        'No JPS/DID river gauge within 15 km, and no river is modelled here '
        '(GloFAS covers larger rivers only).',
        style: TextStyle(fontSize: 12),
      );
    }
    final ratio = rf.riseRatio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No nearby river gauge — using the GloFAS forecast model:',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        if (rf.recentMean != null)
          Text('Recent 7-day average flow: ${rf.recentMean!.toStringAsFixed(1)} m³/s',
              style: const TextStyle(fontSize: 12)),
        if (rf.forecastMax != null)
          Text('Forecast peak (next 7 days): ${rf.forecastMax!.toStringAsFixed(1)} m³/s',
              style: const TextStyle(fontSize: 12)),
        if (ratio != null)
          Text('That is ${ratio.toStringAsFixed(1)}× the recent average.',
              style: const TextStyle(fontSize: 12)),
        if (rf.forecastPeakDate != null)
          Text('Peak expected around ${_formatDate(rf.forecastPeakDate!)}',
              style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text('Source: Open-Meteo Flood API (GloFAS)',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  void _showAreaRiskDetail(AreaRiskResult risk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        Widget detailFor(String factorName) {
          switch (factorName) {
            case 'Historical flood frequency (20km)':
              return _historicalFactorDetail();
            case 'Current rainfall':
              return _rainfallFactorDetail();
            case 'Community reports nearby (5km, 24h)':
              return _reportsFactorDetail(sheetContext);
            case 'Nearby river level':
              return _riverFactorDetail();
            default:
              return const SizedBox.shrink();
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_areaRiskIcon(risk.level),
                        color: _areaRiskColor(risk.level)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${risk.level} flood risk right now',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Text(
                      '${risk.score.toStringAsFixed(0)}/100',
                      style: TextStyle(
                          color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a factor to see how it is scored and the data behind it.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (final factor in risk.factors)
                  _RiskFactorTile(
                    name: factor.factorName,
                    points: factor.scoreContribution,
                    maxPoints: _factorMaxPoints[factor.factorName] ?? 0,
                    summary: factor.factorValue,
                    howScored: _factorHowScored[factor.factorName] ?? '',
                    detail: detailFor(factor.factorName),
                  ),
                const SizedBox(height: 8),
                Text(
                  'A general area indicator for right now — not a substitute for '
                  'running a full property risk assessment.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the nearby community reports behind the Home tab's "Water level"
  /// / "Nearby reports" tiles — the same 5 km / 24 h list [AreaRiskController]
  /// scored. One report opens straight into its detail sheet; several show a
  /// pickable list first.
  void _showNearbyReports() {
    final reports = _nearbyReports;
    if (reports.isEmpty) return;
    if (reports.length == 1) {
      _showReportInfo(reports.first);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                    '${reports.length} nearby flood reports',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Within 5 km, reported in the last 24 hours',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: reports.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final reportedTime = report.createdAt ?? report.observedAt;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.location_on,
                      color: _areaRiskColor(report.waterLevel),
                    ),
                    title: Text(
                      report.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${report.floodType} · ${report.waterLevel} water level · '
                      '${_formatTimeAgo(reportedTime)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      _showReportInfo(report);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Details for the InfoBanjir rain gauge behind the "Rainfall" tile.
  void _showRainfallStationInfo(InfoBanjirStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (station.district != null) Text('District: ${station.district}'),
            const SizedBox(height: 8),
            if (station.rainfall1hMm != null)
              Text('Last 1 hour: ${station.rainfall1hMm!.toStringAsFixed(1)} mm'),
            if (station.rainfall3hMm != null)
              Text('Last 3 hours: ${station.rainfall3hMm!.toStringAsFixed(1)} mm'),
            if (station.rainfallTodayMm != null)
              Text("Today's total: ${station.rainfallTodayMm!.toStringAsFixed(1)} mm"),
            if ((station.rainfallIntensity ?? '').isNotEmpty)
              Text('Intensity: ${station.rainfallIntensity}'),
            const SizedBox(height: 8),
            if (station.rainfallUpdatedAt != null)
              Text(
                'Updated ${_formatTimeAgo(station.rainfallUpdatedAt!)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              'Live reading from a JPS/DID Public InfoBanjir rain gauge — the '
              'nearest one to your current location.',
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
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
      ),
    );
  }

  void _showEvacuationCenterInfo(Facility center) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
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
                      cameraConstraint: kMalaysiaCameraConstraint,
                      interactionOptions: kMapInteractionOptions,
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
                if (!_isLoadingMap && _currentLocation != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            _mapController.move(_currentLocation!, 15),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 22,
                          ),
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
                  caption: _rainfallMm == null
                      ? null
                      : (_rainfallStation != null
                            ? 'gauge, last 1h'
                            : 'forecast est.'),
                  onTap: _rainfallStation == null
                      ? null
                      : () => _showRainfallStationInfo(_rainfallStation!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: "Water level",
                  isLoading: _isLoadingAreaRisk,
                  value: _averageWaterLevel ?? 'No reports nearby',
                  valueColor: _averageWaterLevel == null
                      ? null
                      : _areaRiskColor(_averageWaterLevel),
                  caption: _nearbyReports.length > 1
                      ? 'avg of ${_nearbyReports.length} reports'
                      : null,
                  onTap: _nearbyReports.isEmpty ? null : _showNearbyReports,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: "Nearby reports",
                  isLoading: _isLoadingAreaRisk,
                  value: '${_nearbyReports.length}',
                  caption: 'within 5km, 24h',
                  onTap: _nearbyReports.isEmpty ? null : _showNearbyReports,
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

/// One expandable row in the Flood Risk details sheet: the factor's name and
/// points out of its max, a progress bar, its one-line value; expands to show
/// how it's scored plus the underlying data.
class _RiskFactorTile extends StatelessWidget {
  const _RiskFactorTile({
    required this.name,
    required this.points,
    required this.maxPoints,
    required this.summary,
    required this.howScored,
    required this.detail,
  });

  final String name;
  final double points;
  final double maxPoints;
  final String summary;
  final String howScored;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxPoints <= 0 ? 0.0 : (points / maxPoints).clamp(0.0, 1.0);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 2, bottom: 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Text(
              '${points.toStringAsFixed(0)} / ${maxPoints.toStringAsFixed(0)} pts',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ),
        ),
        children: [
          if (howScored.isNotEmpty) ...[
            Text(
              "How it's scored",
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[800]),
            ),
            const SizedBox(height: 2),
            Text(howScored,
                style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(height: 10),
          ],
          Text(
            'Details',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey[800]),
          ),
          const SizedBox(height: 4),
          detail,
        ],
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
/// [_FloodRiskCard]. Pass [onTap] to make the tile open a detail sheet;
/// it then shows a chevron affordance next to the value.
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isLoading;
  final Color? valueColor;
  final String? caption;
  final VoidCallback? onTap;

  const _StatBox({
    required this.label,
    required this.value,
    required this.isLoading,
    this.valueColor,
    this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null && !isLoading;

    final content = Column(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ),
              if (tappable)
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[600]),
            ],
          ),
        if (!isLoading && caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ],
    );

    return InfoBox(
      child: tappable
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: content,
            )
          : content,
    );
  }
}
