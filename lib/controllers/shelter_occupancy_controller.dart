import '../models/shelter_occupancy_report.dart';
import '../services/shelter_occupancy_service.dart';

class ShelterOccupancyController {
  final ShelterOccupancyService service;

  ShelterOccupancyController(this.service);

  Future<bool> record(ShelterOccupancyReport report) => service.record(report);

  Future<List<ShelterOccupancyReport>> getAll() => service.getAll();

  Future<List<ShelterOccupancyReport>> getForFacility(String facilityId) =>
      service.getForFacility(facilityId);
  Future<Map<String, ShelterOccupancyReport>> getLatestPerFacility() async {
    final all = await getAll(); // already newest-first
    final latest = <String, ShelterOccupancyReport>{};
    for (final report in all) {
      latest.putIfAbsent(report.facilityId, () => report);
    }
    return latest;
  }

  Future<List<ShelterOccupancyReport>> getDailyLog() async {
    final all = await getAll(); // newest recorded_at first
    final seen = <String>{};
    final result = <ShelterOccupancyReport>[];
    for (final report in all) {
      final key = '${report.facilityId}|${report.dateKey}';
      if (seen.add(key)) result.add(report);
    }
    result.sort((a, b) => b.occupancyDate.compareTo(a.occupancyDate));
    return result;
  }
}
