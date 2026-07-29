import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flood_simulation.dart';
import '../models/simulation_factor.dart';
import '../services/risk_assessment_service.dart';
import '../services/flood_simulation_service.dart';
import '../utils/malaysia_geocoding.dart';
import 'historical_flood_controller.dart';
import 'environment_controller.dart';

class SimulationOutcome {
  final FloodSimulation? simulation;
  final List<SimulationFactor> factors;
  final List<String> recommendations;
  final String? error;

  SimulationOutcome({
    required this.simulation,
    required this.factors,
    required this.recommendations,
    this.error,
  });
}

class RiskAssessmentController {
  final HistoricalFloodController historicalFloodController;
  final EnvironmentController environmentController;
  final RiskAssessmentService riskAssessmentService;
  final FloodSimulationService floodSimulationService;

  RiskAssessmentController(
    this.historicalFloodController,
    this.environmentController,
    this.riskAssessmentService,
    this.floodSimulationService,
  );

  /// Gathers historical flood, terrain and weather data for the given
  /// property, scores it, saves the result, and returns the outcome.
  Future<SimulationOutcome> runAssessment({
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

    final nearbyFloods = await historicalFloodController.getNearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: 20,
    );

    final terrain = await environmentController.getTerrain(
      latitude: latitude,
      longitude: longitude,
    );

    final baselineCoord = MalaysiaGeocoder.centroidFor(
      state: state,
      district: district,
    );
    final baselineTerrain = baselineCoord != null
        ? await environmentController.getTerrain(
            latitude: baselineCoord.$1,
            longitude: baselineCoord.$2,
          )
        : null;

    final weather = await environmentController.getWeather(
      latitude: latitude,
      longitude: longitude,
    );

    final propertyElevation = userElevationMeters ?? terrain?.elevationMeters;

    final result = riskAssessmentService.assess(
      RiskAssessmentInput(
        nearbyFloodCount: nearbyFloods.length,
        propertyElevationMeters: propertyElevation,
        baselineElevationMeters: baselineTerrain?.elevationMeters,
        structureType: structureType,
        hasFloodBarriers: hasFloodBarriers,
        hasRaisedFoundation: hasRaisedFoundation,
      ),
    );

    final simulation = FloodSimulation(
      accountId: accountId,
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
      currentWeatherSummary: weather != null
          ? '${weather.description}, ${weather.temperatureCelsius.toStringAsFixed(1)}°C, ${weather.rainfallMm.toStringAsFixed(1)}mm rain'
          : null,
      riskScore: result.score,
      riskLevel: result.level,
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
