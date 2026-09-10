import '../models/infobanjir_station.dart';
import '../models/river_flood_data.dart';
import '../models/terrain_data.dart';
import '../models/weather_data.dart';
import '../services/infobanjir_service.dart';
import '../services/river_flood_service.dart';
import '../services/terrain_service.dart';
import '../services/weather_service.dart';

class EnvironmentController {
  final TerrainService terrainService;
  final WeatherService weatherService;
  final RiverFloodService riverFloodService;
  final InfoBanjirService infoBanjirService;

  EnvironmentController(
    this.terrainService,
    this.weatherService, [
    RiverFloodService? riverFloodService,
    InfoBanjirService? infoBanjirService,
  ])  : riverFloodService = riverFloodService ?? RiverFloodService(),
        infoBanjirService = infoBanjirService ?? InfoBanjirService();

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

  /// Nearest JPS/DID InfoBanjir rain gauge with a fresh reading, or null.
  Future<InfoBanjirStation?> getNearestRainfallStation({
    required double latitude,
    required double longitude,
  }) {
    return infoBanjirService.getNearestRainfallStation(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Nearest JPS/DID InfoBanjir river gauge with a fresh water-level
  /// reading, or null.
  Future<InfoBanjirStation?> getNearestRiverLevelStation({
    required double latitude,
    required double longitude,
  }) {
    return infoBanjirService.getNearestRiverLevelStation(
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
