import '../models/river_flood_data.dart';
import '../models/terrain_data.dart';
import '../models/weather_data.dart';
import '../services/river_flood_service.dart';
import '../services/terrain_service.dart';
import '../services/weather_service.dart';

class EnvironmentController {
  final TerrainService terrainService;
  final WeatherService weatherService;
  final RiverFloodService riverFloodService;

  EnvironmentController(
    this.terrainService,
    this.weatherService, [
    RiverFloodService? riverFloodService,
  ]) : riverFloodService = riverFloodService ?? RiverFloodService();

  Future<TerrainData?> getTerrain({
    required double latitude,
    required double longitude,
  }) {
    return terrainService.getElevation(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<WeatherData?> getWeather({
    required double latitude,
    required double longitude,
  }) {
    return weatherService.getCurrentWeather(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Live river-flood forecast (GloFAS discharge) for the coordinate.
  Future<RiverFloodData?> getRiverFlood({
    required double latitude,
    required double longitude,
  }) {
    return riverFloodService.getRiverFlood(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Terrain and weather for the same coordinate, fetched together since
  /// the risk simulator needs both to assess a selected property.
  Future<({TerrainData? terrain, WeatherData? weather})> getEnvironmentalData({
    required double latitude,
    required double longitude,
  }) async {
    final terrain = await getTerrain(latitude: latitude, longitude: longitude);
    final weather = await getWeather(latitude: latitude, longitude: longitude);
    return (terrain: terrain, weather: weather);
  }
}
