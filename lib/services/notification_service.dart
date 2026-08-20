import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../store/wattwise_store.dart';
import '../models/wattwise_types.dart';

/// Service to manage native push notifications via flutter_local_notifications.
/// Fires real device notifications (notification bar, sound, vibration)
/// whenever the store's alerts change.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Tracks which alert keys have already been pushed as native notifications
  /// so we don't fire duplicates every time the store rebuilds.
  final Set<String> _pushedKeys = {};

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Request notification permission on Android 13+
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }
  }

  /// Call this whenever the store updates. It diffs the current alerts
  /// against what has already been pushed to avoid duplicates.
  Future<void> syncAlerts(WattWiseStore store) async {
    final alerts = store.buildAlerts();
    for (final alert in alerts) {
      if (_pushedKeys.contains(alert.key)) continue;

      _pushedKeys.add(alert.key);
      await _showNotification(alert);
    }
  }

  Future<void> _showNotification(Alert alert) async {
    String channelId;
    String channelName;
    Importance importance;

    switch (alert.tone) {
      case 'danger':
        channelId = 'wattwise_danger';
        channelName = 'Danger Alerts';
        importance = Importance.high;
        break;
      case 'warn':
        channelId = 'wattwise_warning';
        channelName = 'Warning Alerts';
        importance = Importance.high;
        break;
      case 'good':
        channelId = 'wattwise_good';
        channelName = 'Good News';
        importance = Importance.defaultImportance;
        break;
      case 'info':
      default:
        channelId = 'wattwise_info';
        channelName = 'Info Alerts';
        importance = Importance.defaultImportance;
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'WattWise electricity usage alerts',
      importance: importance,
      priority: importance == Importance.high
          ? Priority.high
          : Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      alert.key.hashCode,
      alert.title,
      alert.body,
      details,
    );
  }
}
