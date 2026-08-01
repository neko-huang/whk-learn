import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home/home_screen.dart';
import 'screens/mistakes/mistake_list_screen.dart';
import 'screens/mistakes/add_mistake_screen.dart';
import 'screens/mistakes/mistake_detail_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/schedule/schedule_screen.dart';
import 'screens/plans/plans_screen.dart';
import 'screens/pomodoro/pomodoro_screen.dart';

// ==================== 全局 Provider ====================

/// 深色模式状态
final isDarkModeProvider = StateProvider<bool>((ref) => false);

/// 学段选择
final stageProvider = StateProvider<String>((ref) => 'high_school');

/// 底部导航栏索引
final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

// ==================== 底部导航 Shell ====================

/// 带底部导航栏的主框架
class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  static const _navItems = [
    (icon: Icons.home, label: '首页'),
    (icon: Icons.warning_amber_rounded, label: '易错点'),
    (icon: Icons.calendar_today, label: '课程表'),
    (icon: Icons.assignment, label: '学习计划'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(bottomNavIndexProvider.notifier).state = index;
          navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
        items: _navItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item.icon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}

// ==================== 路由配置 ====================

/// 底部导航栏各分支的路由
final _shellRoutes = <RouteBase>[
  // 分支 0: 首页
  GoRoute(
    path: '/',
    builder: (context, state) => const HomeScreen(),
  ),
  // 分支 1: 易错点
  GoRoute(
    path: '/mistakes',
    builder: (context, state) => const MistakeListScreen(),
    routes: [
      GoRoute(
        path: 'add',
        builder: (context, state) {
          final subjectId = state.uri.queryParameters['subjectId'];
          return AddMistakeScreen(
            initialSubjectId: subjectId != null ? int.tryParse(subjectId) : null,
          );
        },
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MistakeDetailScreen(mistakeId: id);
        },
      ),
    ],
  ),
  // 分支 2: 课程表
  GoRoute(
    path: '/schedule',
    builder: (context, state) => const ScheduleScreen(),
  ),
  // 分支 3: 学习计划
  GoRoute(
    path: '/plans',
    builder: (context, state) => const PlansScreen(),
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // 底部导航 Shell 路由
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: _shellRoutes.map((route) {
          return StatefulShellBranch(routes: [route]);
        }).toList(),
      ),
      // 非底部导航的独立页面
      GoRoute(
        path: '/statistics',
        builder: (context, state) => const StatisticsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/pomodoro',
        builder: (context, state) {
          final subjectId = state.uri.queryParameters['subjectId'];
          final planId = state.uri.queryParameters['planId'];
          return PomodoroScreen(
            initialSubjectId: subjectId != null ? int.tryParse(subjectId) : null,
            initialPlanId: planId != null ? int.tryParse(planId) : null,
          );
        },
      ),
    ],
  );
});

// ==================== 主题配置 ====================

class StudyHelperApp extends ConsumerWidget {
  const StudyHelperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '学助',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  /// 浅色主题
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// 深色主题
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ==================== 用户设置持久化 ====================

class SettingsService {
  /// 保存深色模式设置
  static Future<void> saveDarkMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  /// 保存学段设置
  static Future<void> saveStage(String stage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stage', stage);
  }
}
