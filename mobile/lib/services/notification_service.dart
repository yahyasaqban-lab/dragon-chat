import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }
  
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    // Navigate to the relevant room/chat
  }
  
  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? roomId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'Chat message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: roomId,
    );
  }
  
  Future<void> showCallNotification({
    required String callerName,
    required String roomId,
    bool isVideo = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'calls',
      'Calls',
      channelDescription: 'Incoming call notifications',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      actions: [
        const AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
        const AndroidNotificationAction('decline', 'Decline', cancelNotification: true),
      ],
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(
      0,
      isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
      callerName,
      details,
      payload: roomId,
    );
  }
  
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
  
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
