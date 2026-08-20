import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  RealtimeChannel? _repairRequestChannel;
  RealtimeChannel? _floodReportChannel;

  /// For a resident: notifies when their own request's status changes
  /// (e.g. approved, assigned, completed).
  void watchOwnRepairRequests(String accountId) {
    stopRepairRequestWatch();
    _repairRequestChannel = _supabase
        .channel('repair_request_owner_$accountId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'repair_request',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'requester_id',
            value: accountId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            final oldStatus = payload.oldRecord['status'] as String?;
            if (status == null || status == oldStatus) return;
            NotificationService.instance.showNow(
              id: NotificationService.idAidAssignment,
              title: 'Your request was updated',
              body: 'Status changed to ${status.replaceAll('_', ' ')}.',
            );
          },
        );
    try {
      _repairRequestChannel!.subscribe();
    } catch (error) {
      debugPrint('RealtimeAlertService.watchOwnRepairRequests error: $error');
    }
  }

  /// For a helper: notifies when a request is newly assigned to them.
  void watchAssignedTasks(String accountId) {
    stopRepairRequestWatch();
    _repairRequestChannel = _supabase
        .channel('repair_request_helper_$accountId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'repair_request',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_helper_id',
            value: accountId,
          ),
          callback: (payload) {
            final oldHelperId = payload.oldRecord['assigned_helper_id'] as String?;
            if (oldHelperId == accountId) return; // already assigned, this is some other field change
            NotificationService.instance.showNow(
              id: NotificationService.idAidAssignment,
              title: 'New task assigned to you',
              body: (payload.newRecord['assistance_type'] as String?) ??
                  'A new recovery task was assigned to you.',
            );
          },
        );
    try {
      _repairRequestChannel!.subscribe();
    } catch (error) {
      debugPrint('RealtimeAlertService.watchAssignedTasks error: $error');
    }
  }

  void stopRepairRequestWatch() {
    final channel = _repairRequestChannel;
    if (channel != null) _supabase.removeChannel(channel);
    _repairRequestChannel = null;
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
    stopRepairRequestWatch();
    stopFloodReportWatch();
  }
}
