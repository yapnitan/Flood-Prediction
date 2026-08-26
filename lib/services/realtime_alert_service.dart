import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/helper_district_assignment.dart';
import '../utils/geo_utils.dart';
import 'notification_service.dart';

/// The Task 12 cases that need to react to something happening *elsewhere*
/// (another user submitting a report, an admin assigning a helper) rather
/// than something the current screen just did itself. Subscribes to
/// Supabase Realtime (`postgres_changes`) while the relevant screen is
/// mounted, and surfaces a local notification when a row change matches.
///
/// This only fires while the app is running in the foreground with an
/// active subscription — there's no FCM/Edge Function backend behind it,
/// so it's session-based, not true background push (see NotificationService
/// doc comment).
class RealtimeAlertService {
  RealtimeAlertService._();
  static final RealtimeAlertService instance = RealtimeAlertService._();

  final _supabase = Supabase.instance.client;

  RealtimeChannel? _assetLossReportChannel;
  RealtimeChannel? _floodReportChannel;
  RealtimeChannel? _helperAssignmentChannel;

  /// For a resident: notifies when their own report's status changes
  /// (e.g. verified, rejected).
  void watchOwnAssetLossReports(String accountId) {
    stopAssetLossReportWatch();
    _assetLossReportChannel = _supabase
        .channel('asset_loss_report_owner_$accountId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'asset_loss_report',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: accountId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            final oldStatus = payload.oldRecord['status'] as String?;
            if (status == null || status == oldStatus) return;
            NotificationService.instance.showNow(
              id: NotificationService.idAidAssignment,
              title: 'Your asset loss report was updated',
              body: 'Status changed to ${status.replaceAll('_', ' ')}.',
            );
          },
        );
    try {
      _assetLossReportChannel!.subscribe();
    } catch (error) {
      debugPrint('RealtimeAlertService.watchOwnAssetLossReports error: $error');
    }
  }

  /// For a district-assigned helper: notifies when a new asset loss report
  /// lands in one of their active districts. Realtime filters only support
  /// simple column equality, not a join through `property`, so this
  /// subscribes to all inserts and does one small follow-up query per event
  /// to resolve the report's district — same shape as
  /// [watchNearbyFloodReports]'s client-side distance check below.
  void watchAssignedDistrictReports(
    String helperId, {
    required List<HelperDistrictAssignment> assignments,
  }) {
    stopAssetLossReportWatch();
    final activeDistricts = assignments
        .where((a) => a.isActive)
        .map((a) => '${a.state}|${a.district}')
        .toSet();
    if (activeDistricts.isEmpty) return;

    _assetLossReportChannel = _supabase
        .channel('asset_loss_report_helper_$helperId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'asset_loss_report',
          callback: (payload) async {
            final propertyId = payload.newRecord['property_id'];
            if (propertyId == null) return;
            try {
              final property = await _supabase
                  .from('property')
                  .select('state, district')
                  .eq('id', propertyId)
                  .maybeSingle();
              if (property == null) return;
              final key = '${property['state']}|${property['district']}';
              if (!activeDistricts.contains(key)) return;
              NotificationService.instance.showNow(
                id: NotificationService.idAidAssignment,
                title: 'New asset loss report in your area',
                body: '${payload.newRecord['asset_category'] ?? 'A report'} needs verification in '
                    '${property['district']}.',
              );
            } catch (error) {
              debugPrint('RealtimeAlertService.watchAssignedDistrictReports lookup error: $error');
            }
          },
        );
    try {
      _assetLossReportChannel!.subscribe();
    } catch (error) {
      debugPrint('RealtimeAlertService.watchAssignedDistrictReports error: $error');
    }
  }

  void stopAssetLossReportWatch() {
    final channel = _assetLossReportChannel;
    if (channel != null) _supabase.removeChannel(channel);
    _assetLossReportChannel = null;
  }

  /// For a helper: notifies when the admin assigns them to a new district.
  void watchHelperAssignments(String helperId) {
    stopHelperAssignmentWatch();
    _helperAssignmentChannel = _supabase
        .channel('helper_district_assignment_$helperId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'helper_district_assignment',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'helper_id',
            value: helperId,
          ),
          callback: (payload) {
            final district = payload.newRecord['district'] as String?;
            final state = payload.newRecord['state'] as String?;
            NotificationService.instance.showNow(
              id: NotificationService.idAidAssignment,
              title: 'New area assigned to you',
              body: district != null && state != null
                  ? 'You can now verify asset loss reports in $district, $state.'
                  : 'You have a new district assignment.',
            );
          },
        );
    try {
      _helperAssignmentChannel!.subscribe();
    } catch (error) {
      debugPrint('RealtimeAlertService.watchHelperAssignments error: $error');
    }
  }

  void stopHelperAssignmentWatch() {
    final channel = _helperAssignmentChannel;
    if (channel != null) _supabase.removeChannel(channel);
    _helperAssignmentChannel = null;
  }

  /// Notifies when a newly-submitted flood report lands within [radiusKm]
  /// of [latitude]/[longitude] — a snapshot of the user's location at
  /// watch-start, not continuously tracked.
  void watchNearbyFloodReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) {
    stopFloodReportWatch();
    _floodReportChannel = _supabase
        .channel('flood_report_nearby')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'flood_report',
          callback: (payload) {
            final lat = (payload.newRecord['latitude'] as num?)?.toDouble();
            final lon = (payload.newRecord['longitude'] as num?)?.toDouble();
            if (lat == null || lon == null) return;
            final distanceKm = haversineDistanceKm(
              lat1: latitude,
              lon1: longitude,
              lat2: lat,
              lon2: lon,
            );
            if (distanceKm > radiusKm) return;
            NotificationService.instance.showNow(
              id: NotificationService.idNearbyReport,
              title: 'New flood report nearby',
              body: '${(payload.newRecord['flood_type'] as String?) ?? 'A flood'} reported '
                  '${distanceKm.toStringAsFixed(1)} km away.',
            );
          },
        );
    try {
      _floodReportChannel!.subscribe();
    } catch (error) {
      debugPrint('RealtimeAlertService.watchNearbyFloodReports error: $error');
    }
  }

  void stopFloodReportWatch() {
    final channel = _floodReportChannel;
    if (channel != null) _supabase.removeChannel(channel);
    _floodReportChannel = null;
  }

  void stopAll() {
    stopAssetLossReportWatch();
    stopFloodReportWatch();
    stopHelperAssignmentWatch();
  }
}
