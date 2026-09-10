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

  /// The daily log with "latest replaces" applied — one entry per
  /// (facility, occupancyDate), the one with the newest `recordedAt`.
  /// Newest date first. Drives the admin's per-date resource-cost view.
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
