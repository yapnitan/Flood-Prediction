import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flood_simulation.dart';
import '../models/simulation_factor.dart';
import 'connectivity_service.dart';
import 'offline_sync_service.dart';

/// All Supabase access for the `flood_simulation` / `simulation_factor`
/// tables (Task 3: Flood Risk Assessment).
class FloodSimulationService {
  final supabase = Supabase.instance.client;

  static const String _simulationTable = 'flood_simulation';
  static const String _factorTable = 'simulation_factor';

  Future<FloodSimulation?> createSimulation(
    FloodSimulation simulation,
    List<SimulationFactor> factors,
  ) async {
    try {
      final row = await supabase
          .from(_simulationTable)
          .insert(simulation.toJson())
          .select()
          .single();

      final saved = FloodSimulation.fromJson(row);

      if (factors.isNotEmpty) {
        await supabase
            .from(_factorTable)
            .insert(
              factors
                  .map((f) => f.copyWith(simulationId: saved.id).toJson())
                  .toList(),
            );
      }

      return saved;
    } catch (e) {
      debugPrint('FloodSimulationService.createSimulation error: $e');
      return null;
    }
  }

  /// Task 14 offline support — cached for offline viewing. Simulations
  /// themselves can't be *created* offline (running a fresh assessment
  /// needs live terrain/weather/historical-flood API calls), so unlike
  /// PlannerService there's no write queue here, only a read cache.
  Future<List<FloodSimulation>> getSimulations(String accountId) async {
    final cacheKey = 'flood_simulation_$accountId';
    if (!ConnectivityService.instance.isOnline) {
      return _simulationsFromCache(cacheKey);
    }
    try {
      final rows = await supabase
          .from(_simulationTable)
          .select()
          .eq('account_id', accountId)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows as List);
      await OfflineSyncService.instance.cacheList(cacheKey, list);
      return list.map((r) => FloodSimulation.fromJson(r)).toList();
    } catch (e) {
      debugPrint('FloodSimulationService.getSimulations error: $e');
      return _simulationsFromCache(cacheKey);
    }
  }

  Future<List<FloodSimulation>> _simulationsFromCache(String key) async {
    final cached = await OfflineSyncService.instance.getCachedList(key);
    if (cached == null) return [];
    return cached.map((r) => FloodSimulation.fromJson(r)).toList();
  }

  Future<FloodSimulation?> getSimulationById(String id) async {
    try {
      final row = await supabase
          .from(_simulationTable)
          .select()
          .eq('id', id)
          .maybeSingle();

      return row != null ? FloodSimulation.fromJson(row) : null;
    } catch (e) {
      debugPrint('FloodSimulationService.getSimulationById error: $e');
      return null;
    }
  }

  Future<List<SimulationFactor>> getFactors(String simulationId) async {
    try {
      final rows = await supabase
          .from(_factorTable)
          .select()
          .eq('simulation_id', simulationId)
          .order('score_contribution', ascending: false);

      return (rows as List)
          .map((r) => SimulationFactor.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('FloodSimulationService.getFactors error: $e');
      return [];
    }
  }

  /// Overwrites an existing simulation's saved property/inputs/result and
  /// replaces its factor breakdown (delete + re-insert, same shape as a
  /// fresh [createSimulation] — factors have no independent identity worth
  /// preserving across an edit).
  Future<bool> updateSimulation(
    String id,
    FloodSimulation simulation,
    List<SimulationFactor> factors,
  ) async {
    try {
      await supabase.from(_simulationTable).update(simulation.toJson()).eq('id', id);

      await supabase.from(_factorTable).delete().eq('simulation_id', id);
      if (factors.isNotEmpty) {
        await supabase
            .from(_factorTable)
            .insert(factors.map((f) => f.copyWith(simulationId: id).toJson()).toList());
      }
      return true;
    } catch (e) {
      debugPrint('FloodSimulationService.updateSimulation error: $e');
      return false;
    }
  }

  Future<bool> deleteSimulation(String id) async {
    try {
      await supabase.from(_simulationTable).delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('FloodSimulationService.deleteSimulation error: $e');
      return false;
    }
  }
}
