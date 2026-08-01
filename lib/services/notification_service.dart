import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务 - 艾宾浩斯复习提醒
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 初始化通知服务
  static Future<void> initialize() async {
    if (_initialized) return;

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

    await _notifications.initialize(initSettings);
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  /// 请求通知权限
  static Future<bool> requestPermission() async {
    try {
      final androidGranted = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      final iosGranted = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      return (androidGranted ?? true) || (iosGranted ?? true);
    } catch (e) {
      debugPrint('请求通知权限失败: $e');
      return false;
    }
  }

  /// 安排复习提醒通知
  static Future<void> scheduleReviewNotification({
    required int mistakeId,
    required String title,
    required String subjectName,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // 通知 ID 使用易错点 ID
    final notificationId = mistakeId;

    await _notifications.zonedSchedule(
      notificationId,
      '📚 复习提醒 - $subjectName',
      title,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'review_channel',
          '复习提醒',
          channelDescription: '艾宾浩斯复习提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 取消单个通知
  static Future<void> cancelNotification(int mistakeId) async {
    await _notifications.cancel(mistakeId);
  }

  /// 取消所有通知
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 获取待处理的通知列表
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// 取消特定科目的所有通知
  static Future<void> cancelSubjectNotifications(List<int> mistakeIds) async {
    for (final id in mistakeIds) {
      await _notifications.cancel(id);
    }
  }
}
