import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

const String morningTask = 'morningNotification';
const String afternoonTask = 'afternoonNotification';
const String eveningTask = 'eveningNotification';
const String streakTask = 'streakNotification';

// This runs in background
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final notifications = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(
        const InitializationSettings(android: androidSettings));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'hunter_ascend_channel',
        'Hunter Ascend',
        channelDescription: 'Hunter Ascend Notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    switch (task) {
      case morningTask:
        await notifications.show(1, '⚔️ Rise & Conquer, Hunter!',
            'Your daily missions await. Begin your training now!', details);
        break;
      case afternoonTask:
        await notifications.show(2, '☀️ Midday Check-in',
            'Have you completed your missions today? Stay on track!', details);
        break;
      case eveningTask:
        await notifications.show(3, '🌙 Evening Mission Alert',
            'Last chance to complete today\'s missions. Don\'t give up!', details);
        break;
      case streakTask:
        await notifications.show(4, '🔥 Streak at Risk!',
            'Complete a mission before midnight or lose your streak!', details);
        break;
    }
    return Future.value(true);
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings);



    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Initialize workmanager
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  Future<void> scheduleAllNotifications() async {
    await Workmanager().cancelAll();

    final now = DateTime.now();

    // Morning - 8:00 AM
    await _scheduleDaily(morningTask, 1, 8, 0, now);

    // Afternoon - 1:00 PM
    await _scheduleDaily(afternoonTask, 2, 13, 0, now);

    // Evening - 7:00 PM
    await _scheduleDaily(eveningTask, 3, 19, 0, now);

    // Streak - 9:00 PM
    await _scheduleDaily(streakTask, 4, 21, 0, now);
  }

  Future<void> _scheduleDaily(
      String taskName, int id, int hour, int minute, DateTime now) async {
    DateTime scheduled =
    DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final delay = scheduled.difference(now);

    await Workmanager().registerPeriodicTask(
      '$taskName-$id',
      taskName,
      frequency: const Duration(hours: 24),
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.not_required),
    );
  }

  // Show instant notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hunter_ascend_channel',
          'Hunter Ascend',
          channelDescription: 'Hunter Ascend Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // Show challenge notification
  Future<void> showChallengeNotification({
    required String challengerName,
  }) async {
    await showNotification(
      id: 99,
      title: '⚔️ Challenge Received!',
      body: '$challengerName has challenged you to a Fitness Duel!',
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    await Workmanager().cancelAll();
  }
}