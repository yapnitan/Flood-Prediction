import '../models/flood_report.dart';
import '../models/historical_flood.dart';
import '../models/infobanjir_station.dart';
import '../models/river_flood_data.dart';
import '../services/area_risk_service.dart';
import 'environment_controller.dart';
import 'flood_report_controller.dart';
import 'historical_flood_controller.dart';

/// [AreaRiskResult] plus the raw ingredients that went into it — callers
/// that just want the score/level (e.g. the risk card) only need
/// [result], but callers that want to display a specific input directly
/// (e.g. the Home page's raw rainfall figure or nearby report count) can
/// read it here instead of re-fetching it themselves or parsing it back
/// out of a factor's display string.
class AreaRiskAssessment {
  final AreaRiskResult result;

  /// Rainfall over the last hour (mm). From the nearest InfoBanjir gauge
  /// when [rainfallStation] is set, otherwise the Open-Meteo forecast model.
  final double? currentRainfallMm;

  /// The JPS/DID gauge the rainfall came from, if a fresh one was in range.
  final InfoBanjirStation? rainfallStation;

  final List<FloodReport> nearbyReports;

  /// The JPS/DID historical flood records within 20 km, nearest first — the
  /// raw list behind the "Historical flood frequency" factor.
  final List<HistoricalFlood> nearbyHistoricalFloods;

  /// The nearest InfoBanjir river gauge behind the "Nearby river level"
  /// factor, if one with a fresh reading was in range.
  final InfoBanjirStation? riverStation;

  /// GloFAS discharge window — only the fallback when [riverStation] is null.
  final RiverFloodData? riverFlood;

  AreaRiskAssessment({
    required this.result,
    required this.currentRainfallMm,
    required this.nearbyReports,
    this.rainfallStation,
    this.nearbyHistoricalFloods = const [],
    this.riverStation,
    this.riverFlood,
  });

  bool get rainfallIsFromGauge => rainfallStation != null;
  bool get riverIsFromGauge => riverStation != null;
}

class AreaRiskController {
  final HistoricalFloodController historicalFloodController;
  final EnvironmentController environmentController;
  final FloodReportController floodReportController;
  final AreaRiskService areaRiskService;

  AreaRiskController(
    this.historicalFloodController,
    this.environmentController,
    this.floodReportController,
    this.areaRiskService,
  );

  /// Combines the long-term hazard baseline (historical flood frequency)
  /// with three live signals — current rainfall, nearby community reports
  /// and the nearby river's forecast flow — into a single ambient risk
  /// badge for the given location. Ephemeral: recomputed on demand, never
  /// persisted (unlike [RiskAssessmentController.runAssessment]'s saved
  /// simulations).
  Future<AreaRiskAssessment> assessCurrentLocation({
    required double latitude,
    required double longitude,
  }) async {
    final historicalFuture = historicalFloodController.getNearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: 20,
    );
    final weatherFuture = environmentController.getWeather(
      latitude: latitude,
      longitude: longitude,
    );
    final reportsFuture = floodReportController.getNearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: 5,
      maxAge: const Duration(hours: 24),
    );
    final riverFuture = environmentController.getRiverFlood(
      latitude: latitude,
      longitude: longitude,
    );
    final rainStationFuture = environmentController.getNearestRainfallStation(
      latitude: latitude,
      longitude: longitude,
    );
    final riverStationFuture = environmentController.getNearestRiverLevelStation(
      latitude: latitude,
      longitude: longitude,
    );

    final historical = await historicalFuture;
    final weather = await weatherFuture;
    final reports = await reportsFuture;
    final river = await riverFuture;
    final rainStation = await rainStationFuture;
    final riverStation = await riverStationFuture;

    // Prefer the official JPS/DID gauge's last-hour rainfall; fall back to
    // the Open-Meteo forecast model only when no fresh gauge is in range.
    final rainfallMm = rainStation?.rainfall1hMm ?? weather?.rainfallMm;

    final result = areaRiskService.assess(
      AreaRiskInput(
        nearbyHistoricalFloodCount: historical.length,
        currentRainfallMm: rainfallMm,
        rainfallIntensityLabel: rainStation?.rainfallIntensity,
        nearbyReportWaterLevels: reports.map((r) => r.waterLevel).toList(),
        // River level: InfoBanjir gauge first, GloFAS forecast as fallback.
        riverGaugeStatus: riverStation?.waterLevelStatus,
        riverGaugeRising: riverStation?.isRising ?? false,
        riverFloodLevel: river?.level ?? RiverFloodLevel.unknown,
      ),
    );

    return AreaRiskAssessment(
      result: result,
      currentRainfallMm: rainfallMm,
      rainfallStation: rainStation,
      nearbyReports: reports,
      nearbyHistoricalFloods: historical,
      riverStation: riverStation,
      riverFlood: river,
    );
  }
}
