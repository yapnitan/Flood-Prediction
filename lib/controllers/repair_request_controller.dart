import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/repair_request.dart';
import '../services/repair_request_service.dart';

class RepairRequestController {
  final RepairRequestService repairRequestService;

  RepairRequestController(this.repairRequestService);

  /// For User
  Future<bool> submit(RepairRequest request, List<XFile> photos) {
    return repairRequestService.submit(request, photos);
  }

  Future<List<RepairRequest>> getMyRequests() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    return repairRequestService.getUserRequests(userId);
  }

  Future<RepairRequest?> getRequestById(String requestId) {
    return repairRequestService.getRequestById(requestId);
  }

  Future<void> setFacility(String requestId, String facilityId) async {
    await repairRequestService.updateFields(requestId, {'facility_id': facilityId});
  }

  Future<void> updateRequest(
      String requestId, {
        String? assistanceType,
        String? damageDescription,
        String? facilityId,
        Map<String, dynamic>? details,
      }) async {
    final updates = <String, dynamic>{};
    if (assistanceType != null) updates['assistance_type'] = assistanceType;
    if (damageDescription != null) updates['damage_description'] = damageDescription;
    if (facilityId != null) updates['facility_id'] = facilityId;
    if (details != null) updates['details'] = details;
    if (updates.isEmpty) return;
    await repairRequestService.updateFields(requestId, updates);
  }

  Future<void> cancelRequest(String requestId) async {
    await repairRequestService.updateFields(requestId, {'status': 'cancelled'});
  }

  /// For Admin

  Future<List<Map<String, dynamic>>> getAdminOverview() {
    return repairRequestService.getAllRequestsWithAccountInfo();
  }

  Future<void> approveRequest(String requestId) async {
    await repairRequestService.updateFields(requestId, {'status': 'approved'});
  }

  Future<void> rejectRequest(String requestId) async {
    await repairRequestService.updateFields(requestId, {'status': 'rejected'});
  }

  Future<void> setPriority(String requestId, String priorityLevel) async {
    await repairRequestService.updateFields(requestId, {'priority': priorityLevel});
  }

  Future<void> assignHelper(String requestId, String helperAccountId) async {
    await repairRequestService.updateFields(requestId, {
      'assigned_helper_id': helperAccountId,
      'status': 'assigned',
    });
  }

  /// For Helper

  Future<List<RepairRequest>> getMyAssignedTasks() async {
    final helperId = Supabase.instance.client.auth.currentUser?.id;
    if (helperId == null) return [];
    return repairRequestService.getHelperTasks(helperId);
  }

  Future<void> updateStatus(String requestId, String status) async {
    // valid values for a helper: 'in_progress', 'completed'
    await repairRequestService.updateFields(requestId, {'status': status});
  }
}