import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库
  await DatabaseService.database;

  // 检查日程归档（跨天时标记旧数据为已归档）
  await DatabaseService.archiveAndResetIfNeeded();

  // 初始化通知服务
  await NotificationService.initialize();

  // 调度日程提醒
  _scheduleCalendarReminders();

  // 加载用户设置
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  final selectedStage = prefs.getString('stage') ?? 'high_school';

  runApp(
    ProviderScope(
      overrides: [
        isDarkModeProvider.overrideWith((ref) => isDarkMode),
        stageProvider.overrideWith((ref) => selectedStage),
      ],
      child: const StudyHelperApp(),
    ),
  );

  // 设置系统状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}

/// 调度所有日程提醒
Future<void> _scheduleCalendarReminders() async {
  try {
    final events = await DatabaseService.getEventsWithReminders();
    final eventList = events.map((e) => {'event': e}).toList();
    await NotificationService.scheduleAllCalendarReminders(eventList);
  } catch (_) {
    // 忽略调度错误，不影响应用启动
  }
}
