import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  static NotificationManager get instance => _instance;
  NotificationManager._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification IDs
  static const int _dailyId  = 1;
  static const int _returnId = 2;
  static const int _loseId   = 3;
  static const int _streakId = 4;

  // ── Channels ──────────────────────────────────────────────────────────────
  static const _dailyCh  = AndroidNotificationChannel('daily',  'Daily Reminder',  description: 'Daily play reminders',       importance: Importance.high);
  static const _returnCh = AndroidNotificationChannel('return', 'Return Reminder', description: 'Come back reminders',        importance: Importance.defaultImportance);
  static const _loseCh   = AndroidNotificationChannel('lose',   'Try Again',       description: 'Encouragement after losing', importance: Importance.defaultImportance);
  static const _streakCh = AndroidNotificationChannel('streak', 'Streak Alert',    description: 'Streak notifications',       importance: Importance.high);

  // =========================================================================
  // INIT
  // =========================================================================
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create Android channels
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_dailyCh);
    await androidPlugin?.createNotificationChannel(_returnCh);
    await androidPlugin?.createNotificationChannel(_loseCh);
    await androidPlugin?.createNotificationChannel(_streakCh);

    // Request permissions
    await androidPlugin?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;

    // Schedule standing daily reminder
    await scheduleDailyReminder();
  }

  // =========================================================================
  // DAILY REMINDER — 10:00 AM every day
  // =========================================================================
  Future<void> scheduleDailyReminder() async {
    if (!_initialized) return;

    final now       = tz.TZDateTime.now(tz.local);
    var   scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _dailyId,
      '🎮 Pivot Ball is waiting!',
      'A new challenge is ready. How far can you roll today?',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyCh.id, _dailyCh.name,
          channelDescription: _dailyCh.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // =========================================================================
  // RETURN REMINDER — fires 22 hours after last play
  // =========================================================================
  Future<void> scheduleReturnReminder() async {
    if (!_initialized) return;
    await _plugin.cancel(_returnId);

    final messages = [
      ('⏱ You haven\'t finished yet!',   'Your progress is waiting. Come back and beat your high score!'),
      ('🏆 Your record is in danger!',    'Someone might beat your score. Get back in the game!'),
      ('🎯 One more level?',              'You stopped so close to the next milestone. Let\'s go!'),
    ];
    final msg = messages[DateTime.now().second % messages.length];

    await _plugin.zonedSchedule(
      _returnId,
      msg.$1, msg.$2,
      tz.TZDateTime.now(tz.local).add(const Duration(hours: 22)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _returnCh.id, _returnCh.name,
          channelDescription: _returnCh.description,
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // =========================================================================
  // LOSE REMINDER — fires 40 mins after a loss
  // =========================================================================
  Future<void> scheduleLoseReminder(int level) async {
    if (!_initialized) return;
    await _plugin.cancel(_loseId);

    await _plugin.zonedSchedule(
      _loseId,
      '💪 You were SO close on Level $level!',
      'One more try and you\'ve got it. You can do this!',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 40)),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _loseCh.id, _loseCh.name,
          channelDescription: _loseCh.description,
          importance: Importance.defaultImportance,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // =========================================================================
  // STREAK ALERT — fires at 9 PM if user hasn't played today
  // =========================================================================
  Future<void> scheduleStreakAlert() async {
    if (!_initialized) return;

    final now       = tz.TZDateTime.now(tz.local);
    var   scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _streakId,
      '🔥 Don\'t break your streak!',
      'Play at least one level today to keep your streak alive.',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _streakCh.id, _streakCh.name,
          channelDescription: _streakCh.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelLoseReminder()  async => _plugin.cancel(_loseId);
  Future<void> cancelReturnReminder() async => _plugin.cancel(_returnId);
  Future<void> cancelAll()           async => _plugin.cancelAll();
}
