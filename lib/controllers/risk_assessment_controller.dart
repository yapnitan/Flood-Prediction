import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flood_simulation.dart';
import '../models/river_flood_data.dart';
import '../models/simulation_factor.dart';
import '../models/terrain_data.dart';
import '../services/risk_assessment_service.dart';
import '../services/flood_simulation_service.dart';
import '../services/flood_report_service.dart';
import '../services/connectivity_service.dart';
import '../utils/malaysia_geocoding.dart';
import 'historical_flood_controller.dart';
import 'environment_controller.dart';

class SimulationOutcome {
  final FloodSimulation? simulation;
  final List<SimulationFactor> factors;
  final List<String> recommendations;
  final String? error;
  final bool offline;

  SimulationOutcome({
    required this.simulation,
    required this.factors,
    required this.recommendations,
    this.error,
    this.offline = false,
  });
}

class RiskAssessmentController {
  final HistoricalFloodController historicalFloodController;
  final EnvironmentController environmentController;
  final RiskAssessmentService riskAssessmentService;
  final FloodSimulationService floodSimulationService;
  final FloodReportService floodReportService;

  RiskAssessmentController(
    this.historicalFloodController,
    this.environmentController,
    this.riskAssessmentService,
    this.floodSimulationService, [
    FloodReportService? floodReportService,
  ]) : floodReportService = floodReportService ?? FloodReportService();

  static const _recentReportWindow = Duration(days: 7);
  static const _recentReportRadiusKm = 10.0;

  Future<SimulationOutcome> runAssessment({
    int? propertyId,
    required String propertyName,
    required String structureType,
    required double latitude,
    required double longitude,
    required String state,
    required String district,
    double? userElevationMeters,
    bool hasFloodBarriers = false,
    bool hasRaisedFoundation = false,
  }) async {
    final accountId = Supabase.instance.client.auth.currentUser?.id;
    if (accountId == null) {
      return SimulationOutcome(
        simulation: null,
        factors: [],
        recommendations: [],
        error: 'You must be logged in to run an assessment.',
      );
    }

    final (:simulation, :result) = await _gatherAndScore(
      accountId: accountId,
      propertyId: propertyId,
      propertyName: propertyName,
      structureType: structureType,
      latitude: latitude,
      longitude: longitude,
      state: state,
      district: district,
      userElevationMeters: userElevationMeters,
      hasFloodBarriers: hasFloodBarriers,
      hasRaisedFoundation: hasRaisedFoundation,
    );

    final saved = await floodSimulationService.createSimulation(
      simulation,
      result.factors,
    );

    return SimulationOutcome(
      simulation: saved,
      factors: result.factors,
      recommendations: result.recommendations,
      error: saved == null ? 'Failed to save the assessment.' : null,
    );
  }

  Future<SimulationOutcome> updateAssessment({
    required String simulationId,
    int? propertyId,
    required String propertyName,
    required String structureType,
    required double latitude,
    required double longitude,
    required String state,
    required String district,
    double? userElevationMeters,
    bool hasFloodBarriers = false,
    bool hasRaisedFoundation = false,
  }) async {
    final accountId = Supabase.instance.client.auth.currentUser?.id;
    if (accountId == null) {
      return SimulationOutcome(
        simulation: null,
        factors: [],
        recommendations: [],
        error: 'You must be logged in to update an assessment.',
      );
    }

    final (:simulation, :result) = await _gatherAndScore(
      id: simulationId,
      accountId: accountId,
      propertyId: propertyId,
      propertyName: propertyName,
      structureType: structureType,
      latitude: latitude,
      longitude: longitude,
      state: state,
      district: district,
      userElevationMeters: userElevationMeters,
      hasFloodBarriers: hasFloodBarriers,
      hasRaisedFoundation: hasRaisedFoundation,
    );

    final saved = await floodSimulationService.updateSimulation(
      simulationId,
      simulation,
      result.factors,
    );

    return SimulationOutcome(
      simulation: saved ? simulation : null,
      factors: result.factors,
      recommendations: result.recommendations,
      error: saved ? null : 'Failed to update the assessment.',
    );
  }

  Future<({FloodSimulation simulation, RiskAssessmentResult result})> _gatherAndScore({
    String? id,
    required String accountId,
    int? propertyId,
    required String propertyName,
    required String structureType,
    required double latitude,
    required double longitude,
    required String state,
    required String district,
    double? userElevationMeters,
    required bool hasFloodBarriers,
    required bool hasRaisedFoundation,
  }) async {
    final baselineCoord =
        MalaysiaGeocoder.centroidFor(state: state, district: district);

    final (
      nearbyFloods,
      recentReports,
      riverFlood,
      terrain,
      baselineTerrain,
      weather,
      rainStation,
      riverStation,
    ) = await (
      historicalFloodController.getNearby(
        latitude: latitude,
        longitude: longitude,
        radiusKm: 20,
      ),
      floodReportService.getNearby(
        latitude: latitude,
        longitude: longitude,
        radiusKm: _recentReportRadiusKm,
        maxAge: _recentReportWindow,
      ),
      environmentController.getRiverFlood(
        latitude: latitude,
        longitude: longitude,
      ),
      environmentController.getTerrain(
        latitude: latitude,
        longitude: longitude,
      ),
      baselineCoord != null
          ? environmentController.getTerrain(
              latitude: baselineCoord.$1,
              longitude: baselineCoord.$2,
            )
          : Future<TerrainData?>.value(null),
      environmentController.getWeather(
        latitude: latitude,
        longitude: longitude,
      ),
      environmentController.getNearestRainfallStation(
        latitude: latitude,
        longitude: longitude,
      ),
      environmentController.getNearestRiverLevelStation(
        latitude: latitude,
        longitude: longitude,
      ),
    ).wait;

    final propertyElevation = userElevationMeters ?? terrain?.elevationMeters;
    final rainfallMm = rainStation?.rainfall1hMm ?? weather?.rainfallMm;

    final result = riskAssessmentService.assess(
      RiskAssessmentInput(
        nearbyFloodCount: nearbyFloods.length,
        recentReportWaterLevels:
            recentReports.map((r) => r.waterLevel).toList(),
        rainfallMm: rainfallMm,
        rainfallIntensityLabel: rainStation?.rainfallIntensity,
        riverGaugeStatus: riverStation?.waterLevelStatus,
        riverGaugeRising: riverStation?.isRising ?? false,
        riverFloodLevel: riverFlood?.level ?? RiverFloodLevel.unknown,
        propertyElevationMeters: propertyElevation,
        baselineElevationMeters: baselineTerrain?.elevationMeters,
        structureType: structureType,
        hasFloodBarriers: hasFloodBarriers,
        hasRaisedFoundation: hasRaisedFoundation,
      ),
    );

    final storedRiverLevel = _riverLevelForStorage(
      riverStation?.waterLevelStatus,
      rising: riverStation?.isRising ?? false,
      glofasFallback: riverFlood?.level ?? RiverFloodLevel.unknown,
    );

    final liveConditions = <String>[
      if (weather != null)
        '${weather.description}, ${weather.temperatureCelsius.toStringAsFixed(1)}°C',
      if (rainfallMm != null)
        '${rainfallMm.toStringAsFixed(1)}mm rain in the last hour',
      if (riverStation?.waterLevelStatus != null)
        'river gauge: ${riverStation!.waterLevelStatus}',
    ];

    final simulation = FloodSimulation(
      id: id,
      accountId: accountId,
      propertyId: propertyId,
      propertyName: propertyName,
      structureType: structureType,
      latitude: latitude,
      longitude: longitude,
      state: state,
      district: district,
      userElevationMeters: userElevationMeters,
      terrainElevationMeters: terrain?.elevationMeters,
      baselineElevationMeters: baselineTerrain?.elevationMeters,
      hasFloodBarriers: hasFloodBarriers,
      hasRaisedFoundation: hasRaisedFoundation,
      nearbyFloodCount: nearbyFloods.length,
      recentReportCount: recentReports.length,
      riverFloodLevel: storedRiverLevel,
      currentWeatherSummary:
          liveConditions.isEmpty ? null : liveConditions.join(' · '),
      riskScore: result.score,
      riskLevel: result.level,
    );

    return (simulation: simulation, result: result);
  }

  RiverFloodLevel _riverLevelForStorage(
    String? gaugeStatus, {
    required bool rising,
    required RiverFloodLevel glofasFallback,
  }) {
    if (gaugeStatus == null) return glofasFallback;
    switch (gaugeStatus.toLowerCase()) {
      case 'danger':
      case 'warning':
        return RiverFloodLevel.high;
      case 'alert':
        return RiverFloodLevel.elevated;
      default:
        return rising ? RiverFloodLevel.elevated : RiverFloodLevel.normal;
    }
  }

  Future<SimulationOutcome> refreshSimulation(FloodSimulation simulation) async {
    final id = simulation.id;
    if (id == null) {
      return SimulationOutcome(
        simulation: simulation,
        factors: const [],
        recommendations: const [],
        error: 'This assessment has not been saved yet.',
      );
    }
    if (!ConnectivityService.instance.isOnline) {
      return SimulationOutcome(
        simulation: simulation,
        factors: const [],
        recommendations: const [],
        offline: true,
      );
    }
    return updateAssessment(
      simulationId: id,
      propertyId: simulation.propertyId,
      propertyName: simulation.propertyName,
      structureType: simulation.structureType,
      latitude: simulation.latitude,
      longitude: simulation.longitude,
      state: simulation.state,
      district: simulation.district,
      userElevationMeters: simulation.userElevationMeters,
      hasFloodBarriers: simulation.hasFloodBarriers,
      hasRaisedFoundation: simulation.hasRaisedFoundation,
    );
  }

  Future<List<FloodSimulation>> listSimulations() async {
    final accountId = Supabase.instance.client.auth.currentUser?.id;
    if (accountId == null) return [];
    return floodSimulationService.getSimulations(accountId);
  }

  Future<List<SimulationFactor>> getFactors(String simulationId) {
    return floodSimulationService.getFactors(simulationId);
  }

  Future<bool> deleteSimulation(String id) {
    return floodSimulationService.deleteSimulation(id);
  }
}
