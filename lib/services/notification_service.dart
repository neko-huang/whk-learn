import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务 - 艾宾浩斯复习提醒
class NotificationService {
  /// 日历事项通知 ID 偏移量，避免与复习提醒通知 ID 冲突
  static const int calendarNotificationOffset = 100000;
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

  // ==================== 日程提醒相关 ====================

  /// 安排日程提醒通知（使用日历事项 ID + 固定偏移避免冲突）
  static Future<void> scheduleCalendarEventNotification({
    required int eventId,
    required String title,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // 使用 calendarNotificationOffset + eventId 作为通知 ID，避免与复习提醒 ID 冲突
    final notificationId = calendarNotificationOffset + eventId;

    await _notifications.zonedSchedule(
      notificationId,
      '📅 日程提醒',
      title,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'calendar_channel',
          '日程提醒',
          channelDescription: '日历事项提醒通知',
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

  /// 取消日历事项通知
  static Future<void> cancelCalendarEventNotification(int eventId) async {
    await _notifications.cancel(calendarNotificationOffset + eventId);
  }

  /// 批量调度所有日程提醒（先取消旧通知，再创建新通知）
  static Future<void> scheduleAllCalendarReminders(
      List<Map<String, dynamic>> events) async {
    if (!_initialized) {
      await initialize();
    }

    // 先取消所有旧日历通知，避免修改事件时间后旧通知仍弹出
    final pending = await _notifications.pendingNotificationRequests();
    for (final req in pending) {
      if (req.id >= calendarNotificationOffset) {
        await _notifications.cancel(req.id);
      }
    }

    final now = DateTime.now();

    for (final eventData in events) {
      final event = eventData['event'] as dynamic;
      final eventId = event.id as int;
      final title = event.title as String;
      final reminderMinutes = event.reminderMinutesBefore as int? ?? 0;

      String? timeStr;
      DateTime? eventDate;

      if (event.eventType == 'one_time') {
        eventDate = event.eventDate;
        timeStr = event.eventTime;
      } else if (event.eventType == 'long_term') {
        // 长期安排：计算今天或最近的日期
        final weekday = event.repeatWeekday;
        if (weekday == null) continue;
        timeStr = event.repeatStartTime;
        final todayWeekday = now.weekday;
        int daysUntil = weekday - todayWeekday;
        if (daysUntil < 0) daysUntil += 7;
        eventDate = DateTime(now.year, now.month, now.day + daysUntil);
      }

      if (eventDate == null || timeStr == null || timeStr.isEmpty) continue;

      try {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final reminderTime = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          hour,
          minute,
        ).subtract(Duration(minutes: reminderMinutes));

        // 只安排未来的提醒
        if (reminderTime.isAfter(now)) {
          await scheduleCalendarEventNotification(
            eventId: eventId,
            title: title,
            scheduledDate: reminderTime,
          );
        }
      } catch (_) {
        continue;
      }
    }
  }
}
