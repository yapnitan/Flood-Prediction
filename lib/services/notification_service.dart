import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wraps [FlutterLocalNotificationsPlugin] for every CLAUDE.md Task 12
/// notification case this app can genuinely support without a server-side
/// push backend (no Firebase Cloud Messaging project is configured here):
///
/// - Checklist reminders: a real scheduled local notification, fires even
///   if the app is closed.
/// - Nearby flood reports / weather warnings / aid assignment updates /
///   simulation completion: fired immediately, in response to something
///   that happened *while the app is running* (a Supabase Realtime event,
///   or a computed threshold check) — not true background push.
///
/// See [callers in `user_view.dart`/`helper_view.dart`/`home_flood_overview.dart`]
/// for where each case is wired up.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'flood_watch_alerts';
  static const _channelName = 'Flood Watch Alerts';
  static const _channelDescription =
      'Flood reports, weather warnings, checklist reminders, and status updates';

  /// Notification ids — fixed per case so re-showing/canceling a case
  /// replaces its previous notification instead of stacking duplicates.
  static const idChecklistReminder = 1001;
  static const idSimulationCompletion = 1002;
  static const idAidAssignment = 1003;
  static const idNearbyReport = 1004;
  static const idWeatherWarning = 1005;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimeZone.identifier));
    } catch (error) {
      debugPrint('NotificationService: could not resolve device timezone, defaulting to UTC: $error');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(_channelId, _channelName, description: _channelDescription),
    );
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> showNow({required int id, required String title, required String body}) async {
    try {
      await _plugin.show(id, title, body, _details);
    } catch (error) {
      debugPrint('NotificationService.showNow error: $error');
    }
  }

  /// Schedules a daily reminder at [hour]:[minute] local time — used for
  /// "you still have unchecked emergency-checklist items" while
  /// preparation is incomplete. Re-calling this replaces any existing
  /// reminder (same [idChecklistReminder]) rather than stacking a second
  /// one.
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    int hour = 9,
    int minute = 0,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      debugPrint('NotificationService.scheduleDailyReminder error: $error');
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
