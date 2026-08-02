import '../services/area_risk_service.dart';
import 'environment_controller.dart';
import 'flood_report_controller.dart';
import 'historical_flood_controller.dart';

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
  /// with two live signals — current rainfall and nearby community
  /// reports — into a single ambient risk badge for the given location.
  /// Ephemeral: recomputed on demand, never persisted (unlike
  /// [RiskAssessmentController.runAssessment]'s saved simulations).
  Future<AreaRiskResult> assessCurrentLocation({
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

    final historical = await historicalFuture;
    final weather = await weatherFuture;
    final reports = await reportsFuture;

    return areaRiskService.assess(
      AreaRiskInput(
        nearbyHistoricalFloodCount: historical.length,
        currentRainfallMm: weather?.rainfallMm,
        nearbyReportWaterLevels: reports.map((r) => r.waterLevel).toList(),
      ),
    );
  }
}
