import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';

/// 当前学段的可见科目 Provider
final stageSubjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final stage = ref.watch(stageProvider);
  return await DatabaseService.getVisibleSubjects(stage: stage);
});

/// 今日概览 Provider
final todayStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  return await DatabaseService.getTodayStats();
});

/// 待复习易错点 Provider（按学段过滤）
final pendingReviewsProvider = FutureProvider<List<MistakeWithSubject>>((ref) async {
  final stage = ref.watch(stageProvider);
  final subjects = await DatabaseService.getVisibleSubjects(stage: stage);
  final subjectIds = subjects.map((s) => s.id).toSet();
  
  // 获取所有需要复习的，然后按学段过滤
  final all = await DatabaseService.getMistakes(needsReview: true);
  return all.where((m) => subjectIds.contains(m.mistake.subjectId)).toList();
});

/// 首页
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(todayStatsProvider);
    final reviews = ref.watch(pendingReviewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📚 学助',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/mistakes'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayStatsProvider);
          ref.invalidate(pendingReviewsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 今日统计卡片
                _buildStatsCard(context, stats),
                const SizedBox(height: 24),

                // 快捷操作
                _buildQuickActions(context),
                const SizedBox(height: 24),

                // 待复习区域
                _buildReviewSection(context, reviews),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/mistakes/add'),
        icon: const Icon(Icons.add),
        label: const Text('记录易错点'),
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCard(BuildContext context, AsyncValue<Map<String, int>> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 今日概览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            stats.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载失败: $e'),
              data: (data) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.note_add,
                    label: '今日新增',
                    value: '${data['newMistakes'] ?? 0}',
                    color: Colors.blue,
                  ),
                  _buildStatItem(
                    icon: Icons.pending_actions,
                    label: '待复习',
                    value: '${data['reviewCount'] ?? 0}',
                    color: Colors.orange,
                  ),
                  _buildStatItem(
                    icon: Icons.library_books,
                    label: '总计',
                    value: '${data['totalMistakes'] ?? 0}',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  /// 快捷操作
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.camera_alt,
                label: '拍照记录',
                onTap: () => context.push('/mistakes/add'),
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.timer,
                label: '番茄钟',
                onTap: () => context.push('/pomodoro'),
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.bar_chart,
                label: '学习统计',
                onTap: () => context.push('/statistics'),
                color: Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.chat,
                label: 'DeepSeek',
                onTap: () => context.push('/deepseek'),
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.calendar_today,
                label: '课程表',
                onTap: () => context.go('/schedule'),
                color: Colors.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.assignment,
                label: '学习计划',
                onTap: () => context.go('/plans'),
                color: Colors.amber.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.phone_android,
                label: '离开手机',
                onTap: () => context.push('/focus-mode'),
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.view_timeline,
                label: '日程规划',
                onTap: () => context.go('/daily-schedule'),
                color: Colors.brown,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.calendar_month,
                label: '日历',
                onTap: () => context.push('/calendar'),
                color: Colors.pink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  /// 待复习区域
  Widget _buildReviewSection(BuildContext context, AsyncValue<List<MistakeWithSubject>> reviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🔔 待复习',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.push('/mistakes'),
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        reviews.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载失败: $e'),
          data: (data) {
            if (data.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.celebration, size: 48, color: Colors.green.shade300),
                        const SizedBox(height: 12),
                        const Text('暂无待复习内容', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text('太棒了！继续保持 ✨', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: data.take(3).map((item) => _buildReviewCard(context, item)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReviewCard(BuildContext context, MistakeWithSubject item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.subject.displayColor,
          child: Text(
            item.subject.name.substring(0, 1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          item.mistake.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${item.subject.name}${item.mistake.chapter.isNotEmpty ? ' · ${item.mistake.chapter}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: item.reviewUrgency == ReviewUrgency.overdue
                ? Colors.red.shade100
                : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.reviewUrgency == ReviewUrgency.overdue ? '逾期' : '今天',
            style: TextStyle(
              color: item.reviewUrgency == ReviewUrgency.overdue ? Colors.red : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        onTap: () => context.push('/mistakes/${item.mistake.id}'),
      ),
    );
  }

  }
