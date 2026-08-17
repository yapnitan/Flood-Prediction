import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/facility.dart';

class FacilityService {
  FacilityService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'facilities';

  final SupabaseClient _supabase;

  Future<List<Facility>> getAllFacilities() async {
    final data = await _supabase.from(_table).select().order('name');
    return (data as List).map((e) => Facility.fromJson(e)).toList();
  }

  Future<List<Facility>> getFacilitiesByType(
      String facilityType, {
        bool activeOnly = true,
      }) async {
    var query = _supabase.from(_table).select().eq('facility_type', facilityType);
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final data = await query.order('name');
    return (data as List).map((e) => Facility.fromJson(e)).toList();
  }

  Future<Facility?> getFacilityById(String facilityId) async {
    final data =
    await _supabase.from(_table).select().eq('id', facilityId).maybeSingle();
    return data == null ? null : Facility.fromJson(data);
  }

  Future<bool> createFacility(Facility facility) async {
    try {
      await _supabase.from(_table).insert(facility.toJson());
      return true;
    } catch (error) {
      debugPrint('FacilityService.createFacility error: $error');
      return false;
    }
  }

  Future<void> updateFields(String facilityId, Map<String, dynamic> updates) async {
    await _supabase.from(_table).update(updates).eq('id', facilityId);
  }
}