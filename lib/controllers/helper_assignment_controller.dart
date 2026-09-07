import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/helper_district_assignment.dart';
import '../services/helper_assignment_service.dart';

class HelperAssignmentController {
  final HelperAssignmentService service;

  HelperAssignmentController(this.service);

  Future<List<Map<String, dynamic>>> getAllWithHelperInfo() => service.getAllWithHelperInfo();

  Future<List<HelperDistrictAssignment>> getMyAssignments() async {
    final helperId = Supabase.instance.client.auth.currentUser?.id;
    if (helperId == null) return [];
    return service.getMyAssignments(helperId);
  }

  Future<String?> assign(HelperDistrictAssignment assignment) => service.assign(assignment);

  Future<String?> deactivate(String id) => service.setStatus(id, 'inactive');

  Future<String?> reactivate(String id) => service.setStatus(id, 'active');

  Future<String?> reassign({
    required String? existingAssignmentId,
    required String helperId,
    required String state,
    required String district,
  }) {
    return service.reassign(
      existingAssignmentId: existingAssignmentId,
      helperId: helperId,
      state: state,
      district: district,
    );
  }
}
