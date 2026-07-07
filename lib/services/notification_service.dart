import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    await Permission.notification.request();
    _initialized = true;
  }

  static Future<void> showMessageNotification({
    required String senderNumber,
    required String message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Messages',
      channelDescription: 'Chat messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin.show(
      1,
      'Message from ${senderNumber.substring(0, 3)}***${senderNumber.substring(17)}',
      message,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> showCallNotification({
    required String callerNumber,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'calls_channel',
      'Incoming Calls',
      channelDescription: 'Call requests',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      ongoing: true,
    );
    await _plugin.show(
      2,
      'Incoming Call Request',
      'From: ${callerNumber.substring(0, 3)}***${callerNumber.substring(17)}',
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancelCallNotification() async {
    await _plugin.cancel(2);
  }
}
