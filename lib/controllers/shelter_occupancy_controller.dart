import '../models/shelter_occupancy_report.dart';
import '../services/shelter_occupancy_service.dart';

class ShelterOccupancyController {
  final ShelterOccupancyService service;

  ShelterOccupancyController(this.service);

  Future<bool> record(ShelterOccupancyReport report) => service.record(report);

  Future<List<ShelterOccupancyReport>> getAll() => service.getAll();

  Future<List<ShelterOccupancyReport>> getForFacility(String facilityId) =>
      service.getForFacility(facilityId);

  /// Reduces the full log to one (the most recent) entry per facility —
  /// "current occupancy snapshot", not a running total (see
  /// 0026_create_shelter_occupancy_report.sql).
  Future<Map<String, ShelterOccupancyReport>> getLatestPerFacility() async {
    final all = await getAll(); // already newest-first
    final latest = <String, ShelterOccupancyReport>{};
    for (final report in all) {
      latest.putIfAbsent(report.facilityId, () => report);
    }
    return latest;
  }
}
