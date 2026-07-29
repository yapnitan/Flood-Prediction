import '../models/historical_flood.dart';
import '../services/historical_flood_service.dart';

class HistoricalFloodController {
  final HistoricalFloodService historicalFloodService;

  HistoricalFloodController(this.historicalFloodService);

  Future<List<HistoricalFlood>> search({
    String? state,
    String? district,
    String? riverBasin,
    String? floodCause,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = HistoricalFloodService.defaultPageSize,
  }) {
    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize < 1 ? HistoricalFloodService.defaultPageSize : pageSize;

    return historicalFloodService.search(
      state: state,
      district: district,
      riverBasin: riverBasin,
      floodCause: floodCause,
      startDate: startDate,
      endDate: endDate,
      page: safePage,
      pageSize: safePageSize,
    );
  }

  Future<HistoricalFlood?> getById(String id) {
    return historicalFloodService.getById(id);
  }

  Future<List<HistoricalFlood>> getNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 20,
    int limit = 50,
  }) {
    return historicalFloodService.getNearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      limit: limit,
    );
  }

  Future<int> importRecords(List<HistoricalFlood> records) {
    return historicalFloodService.importRecords(records);
  }
}
