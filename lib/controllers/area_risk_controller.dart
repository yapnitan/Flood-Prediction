import '../models/flood_report.dart';
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
  final double? currentRainfallMm;
  final List<FloodReport> nearbyReports;

  AreaRiskAssessment({
    required this.result,
    required this.currentRainfallMm,
    required this.nearbyReports,
  });
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

    final historical = await historicalFuture;
    final weather = await weatherFuture;
    final reports = await reportsFuture;
    final river = await riverFuture;

    final result = areaRiskService.assess(
      AreaRiskInput(
        nearbyHistoricalFloodCount: historical.length,
        currentRainfallMm: weather?.rainfallMm,
        nearbyReportWaterLevels: reports.map((r) => r.waterLevel).toList(),
        riverFloodLevel: river?.level ?? RiverFloodLevel.unknown,
      ),
    );

    return AreaRiskAssessment(
      result: result,
      currentRainfallMm: weather?.rainfallMm,
      nearbyReports: reports,
    );
  }
}
