import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shelter_occupancy_report.dart';

class ShelterOccupancyService {
  ShelterOccupancyService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'shelter_occupancy_report';

  final SupabaseClient _supabase;

  Future<bool> record(ShelterOccupancyReport report) async {
    final recordedBy = _supabase.auth.currentUser?.id;
    if (recordedBy == null) return false;
    try {
      await _supabase.from(_table).insert(
        ShelterOccupancyReport(
          facilityId: report.facilityId,
          recordedBy: recordedBy,
          adults: report.adults,
          children: report.children,
          elderly: report.elderly,
          infants: report.infants,
          personsWithDisabilities: report.personsWithDisabilities,
          days: report.days,
        ).toJson(),
      );
      return true;
    } catch (error) {
      debugPrint('ShelterOccupancyService.record error: $error');
      return false;
    }
  }

  /// Newest-first across all shelters — callers reduce this to "latest row
  /// per facility" themselves (matches the project's existing convention of
  /// aggregating flat rows client-side rather than via a Postgres view).
  Future<List<ShelterOccupancyReport>> getAll() async {
    final data = await _supabase.from(_table).select().order('recorded_at', ascending: false);
    return (data as List).map((e) => ShelterOccupancyReport.fromJson(e)).toList();
  }

  Future<List<ShelterOccupancyReport>> getForFacility(String facilityId) async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('facility_id', facilityId)
        .order('recorded_at', ascending: false);
    return (data as List).map((e) => ShelterOccupancyReport.fromJson(e)).toList();
  }
}
