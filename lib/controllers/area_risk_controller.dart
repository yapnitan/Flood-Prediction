import '../models/flood_report.dart';
import '../models/historical_flood.dart';
import '../models/infobanjir_station.dart';
import '../models/river_flood_data.dart';
import '../services/area_risk_service.dart';
import 'environment_controller.dart';
import 'flood_report_controller.dart';
import 'historical_flood_controller.dart';


class AreaRiskAssessment {
  final AreaRiskResult result;

  final double? currentRainfallMm;

  final InfoBanjirStation? rainfallStation;

  final List<FloodReport> nearbyReports;

  final List<HistoricalFlood> nearbyHistoricalFloods;

  final InfoBanjirStation? riverStation;

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

    final rainfallMm = rainStation?.rainfall1hMm ?? weather?.rainfallMm;

    final result = areaRiskService.assess(
      AreaRiskInput(
        nearbyHistoricalFloodCount: historical.length,
        currentRainfallMm: rainfallMm,
        rainfallIntensityLabel: rainStation?.rainfallIntensity,
        nearbyReportWaterLevels: reports.map((r) => r.waterLevel).toList(),
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
