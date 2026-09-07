import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flood_incident.dart';

class FloodIncidentService {
  FloodIncidentService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'flood_incident';

  final SupabaseClient _supabase;

  Future<List<FloodIncident>> getAll() async {
    final data = await _supabase.from(_table).select().order('started_at', ascending: false);
    return (data as List).map((e) => FloodIncident.fromJson(e)).toList();
  }

  Future<List<FloodIncident>> getActive() async {
    final data = await _supabase
        .from(_table)
        .select()
        .filter('ended_at', 'is', null)
        .order('started_at', ascending: false);
    return (data as List).map((e) => FloodIncident.fromJson(e)).toList();
  }

  Future<bool> create(FloodIncident incident) async {
    try {
      await _supabase.from(_table).insert(incident.toJson());
      return true;
    } catch (error) {
      debugPrint('FloodIncidentService.create error: $error');
      return false;
    }
  }

  Future<void> close(String id) async {
    await _supabase
        .from(_table)
        .update({'ended_at': DateTime.now().toIso8601String().split('T').first})
        .eq('id', id);
  }
}
