import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/helper_district_assignment.dart';

class HelperAssignmentService {
  HelperAssignmentService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'helper_district_assignment';

  final SupabaseClient _supabase;

  /// Admin overview, joined with the helper's account so the assignment
  /// list can show a name instead of a raw id.
  Future<List<Map<String, dynamic>>> getAllWithHelperInfo() async {
    final data = await _supabase
        .from(_table)
        .select('*, account:helper_id(name, email)')
        .order('assigned_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<HelperDistrictAssignment>> getMyAssignments(String helperId) async {
    final data = await _supabase
        .from(_table)
        .select()
        .eq('helper_id', helperId)
        .eq('status', 'active')
        .order('assigned_at', ascending: false);
    return (data as List).map((e) => HelperDistrictAssignment.fromJson(e)).toList();
  }

  /// Returns a user-facing error message on failure, or null on success.
  /// A 23505 unique-index conflict is either "this district already has an
  /// active helper" (0024) or "this helper is already assigned to a place"
  /// (0042) — the constraint name tells them apart.
  Future<String?> assign(HelperDistrictAssignment assignment) async {
    try {
      await _supabase.from(_table).insert(assignment.toJson());
      return null;
    } on PostgrestException catch (e) {
      debugPrint('HelperAssignmentService.assign error: $e');
      if (e.code == '23505') {
        if (e.message.contains('active_helper')) {
          return 'This helper is already assigned to a place. Change their '
              'place instead of adding another.';
        }
        return '${assignment.district}, ${assignment.state} already has an active helper assignment.';
      }
      return 'Could not create the assignment. Please try again.';
    } catch (error) {
      debugPrint('HelperAssignmentService.assign error: $error');
      return 'Could not create the assignment. Please try again.';
    }
  }

  /// Returns a user-facing error message on failure (e.g. reactivating
  /// would collide with another district's now-active assignment), or null
  /// on success.
  Future<String?> setStatus(String id, String status) async {
    try {
      await _supabase
          .from(_table)
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      return null;
    } on PostgrestException catch (e) {
      debugPrint('HelperAssignmentService.setStatus error: $e');
      if (e.code == '23505') {
        return e.message.contains('active_helper')
            ? 'This helper already has an active place. Deactivate it first.'
            : 'That district already has another active helper assignment.';
      }
      return 'Could not update the assignment. Please try again.';
    } catch (error) {
      debugPrint('HelperAssignmentService.setStatus error: $error');
      return 'Could not update the assignment. Please try again.';
    }
  }

  /// Deactivates [existingAssignmentId] (if any) and assigns [helperId] to
  /// the same district in one call — the admin-facing "replace" action for
  /// the one-active-helper-per-district conflict.
  Future<String?> reassign({
    required String? existingAssignmentId,
    required String helperId,
    required String state,
    required String district,
  }) async {
    if (existingAssignmentId != null) {
      await setStatus(existingAssignmentId, 'inactive');
    }
    return assign(HelperDistrictAssignment(
      helperId: helperId,
      state: state,
      district: district,
    ));
  }
}
