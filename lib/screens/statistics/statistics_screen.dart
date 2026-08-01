import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/database_service.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';

/// 统计数据 Provider
final statisticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = await DatabaseService.database;
  
  // 获取所有科目
  final subjects = await DatabaseService.getAllSubjects();
  
  // 获取所有易错点
  final mistakes = await db.select(db.mistakes).get();
  
  // 按科目统计
  Map<int, int> mistakesBySubject = {};
  Map<int, int> reviewedBySubject = {};
  
  for (final mistake in mistakes) {
    mistakesBySubject[mistake.subjectId] = (mistakesBySubject[mistake.subjectId] ?? 0) + 1;
    if (mistake.reviewCount > 0) {
      reviewedBySubject[mistake.subjectId] = (reviewedBySubject[mistake.subjectId] ?? 0) + 1;
    }
  }

  // 最近7天趋势
  final now = DateTime.now();
  final List<MapEntry<DateTime, int>> dailyTrend = [];
  for (int i = 6; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    
    final count = mistakes.where((m) => 
      m.createdAt.isAfter(dayStart) && 
      m.createdAt.isBefore(dayEnd)
    ).length;
    
    dailyTrend.add(MapEntry(dayStart, count));
  }

  // 复习完成率
  final totalMistakes = mistakes.length;
  final reviewedMistakes = mistakes.where((m) => m.reviewCount > 0).length;
  final reviewRate = totalMistakes > 0 ? reviewedMistakes / totalMistakes : 0.0;

  // 难度分布
  Map<int, int> difficultyDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  for (final mistake in mistakes) {
    difficultyDistribution[mistake.difficultyLevel] = 
      (difficultyDistribution[mistake.difficultyLevel] ?? 0) + 1;
  }

  // ===== 番茄钟相关统计 =====
  
  // 今日学习时长
  final todayStudyMinutes = await DatabaseService.getTodayStudyMinutes();
  
  // 今日番茄钟数量
  final todayPomodoroCount = await DatabaseService.getTodayPomodoroCount();
  
  // 连续打卡天数
  final studyStreak = await DatabaseService.getStudyStreak();
  
  // 各科目学习时长分布（从番茄钟记录）
  final subjectStudyDistribution = await DatabaseService.getSubjectStudyDistribution();
  
  // 最近7天每日学习时长（从番茄钟）
  final dailyStudyMinutes = await DatabaseService.getDailyStudyMinutes(7);

  // 专注模式完成次数
  final todayFocusModeCount = await DatabaseService.getTodayFocusModeCount();

  return {
    'subjects': subjects,
    'mistakesBySubject': mistakesBySubject,
    'reviewedBySubject': reviewedBySubject,
    'dailyTrend': dailyTrend,
    'totalMistakes': totalMistakes,
    'reviewedMistakes': reviewedMistakes,
    'reviewRate': reviewRate,
    'difficultyDistribution': difficultyDistribution,
    // 番茄钟统计
    'todayStudyMinutes': todayStudyMinutes,
    'todayPomodoroCount': todayPomodoroCount,
    'studyStreak': studyStreak,
    'subjectStudyDistribution': subjectStudyDistribution,
    'dailyStudyMinutes': dailyStudyMinutes,
    // 专注模式统计
    'todayFocusModeCount': todayFocusModeCount,
  };
});

/// 统计页面
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习统计'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statisticsProvider);
        },
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (data) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 今日学习概况
                _buildTodayStudyCard(data),
                const SizedBox(height: 20),

                // 总览卡片
                _buildOverviewCard(data),
                const SizedBox(height: 20),

                // 7天学习时长趋势
                _buildStudyTrendChart(context, data),
                const SizedBox(height: 20),

                // 7天易错点趋势
                _buildTrendChart(data),
                const SizedBox(height: 20),

                // 科目学习时间分布（番茄钟）
                _buildSubjectStudyPieChart(context, data),
                const SizedBox(height: 20),

                // 科目易错点分布
                _buildSubjectChart(context, data),
                const SizedBox(height: 20),

                // 难度分布
                _buildDifficultyChart(data),
                const SizedBox(height: 20),

                // 复习进度
                _buildReviewProgress(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 今日学习概况卡片
  Widget _buildTodayStudyCard(Map<String, dynamic> data) {
    final todayMinutes = data['todayStudyMinutes'] as int;
    final todayCount = data['todayPomodoroCount'] as int;
    final streak = data['studyStreak'] as int;
    final focusModeCount = data['todayFocusModeCount'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🍅 今日学习',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStudyStatColumn(
                  '学习时长',
                  _formatMinutes(todayMinutes),
                  Colors.red,
                  Icons.timer,
                ),
                _buildStudyStatColumn(
                  '番茄数',
                  '$todayCount',
                  Colors.orange,
                  Icons.local_fire_department,
                ),
                _buildStudyStatColumn(
                  '专注模式',
                  '$focusModeCount',
                  Colors.deepPurple,
                  Icons.phone_android,
                ),
                _buildStudyStatColumn(
                  '连续打卡',
                  '$streak天',
                  Colors.green,
                  Icons.trending_up,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyStatColumn(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  /// 总览卡片
  Widget _buildOverviewCard(Map<String, dynamic> data) {
    final total = data['totalMistakes'] as int;
    final reviewed = data['reviewedMistakes'] as int;
    final rate = data['reviewRate'] as double;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 易错点总览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('总记录', '$total', Colors.blue),
                _buildStatColumn('已复习', '$reviewed', Colors.green),
                _buildStatColumn('完成率', '${(rate * 100).toInt()}%', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  /// 7天学习时长趋势图
  Widget _buildStudyTrendChart(BuildContext context, Map<String, dynamic> data) {
    final dailyMinutes = data['dailyStudyMinutes'] as List<MapEntry<DateTime, int>>;
    final maxValue = dailyMinutes.map((e) => e.value).fold(0, (a, b) => a > b ? a : b);

    if (maxValue == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⏱ 学习时长趋势',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无学习记录', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⏱ 学习时长趋势（分钟）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxValue + 10).toDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final minutes = rod.toY.toInt();
                        return BarTooltipItem(
                          '$minutes 分钟',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < dailyMinutes.length) {
                            final date = dailyMinutes[value.toInt()].key;
                            return Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: dailyMinutes.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: Colors.orange,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 7天易错点趋势图
  Widget _buildTrendChart(Map<String, dynamic> data) {
    final trend = data['dailyTrend'] as List<MapEntry<DateTime, int>>;
    final maxValue = trend.map((e) => e.value).fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 最近7天（易错点）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxValue + 2).toDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < trend.length) {
                            final date = trend[value.toInt()].key;
                            return Text(
                              '${date.month}/${date.day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: trend.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: Colors.blue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 科目学习时间分布饼图（从番茄钟记录）
  Widget _buildSubjectStudyPieChart(BuildContext context, Map<String, dynamic> data) {
    final subjects = data['subjects'] as List<Subject>;
    final distribution = data['subjectStudyDistribution'] as Map<int, int>;

    if (distribution.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎯 科目学习时间',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无学习记录', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final subjectMap = {for (var s in subjects) s.id: s};
    final chartSubjects = distribution.keys
        .where((id) => subjectMap.containsKey(id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎯 科目学习时间',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 0,
                        sections: chartSubjects.map((id) {
                          final minutes = distribution[id] ?? 0;
                          final subject = subjectMap[id]!;
                          return PieChartSectionData(
                            value: minutes.toDouble(),
                            color: subject.displayColor,
                            radius: 60,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: chartSubjects.map((id) {
                        final minutes = distribution[id] ?? 0;
                        final subject = subjectMap[id]!;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: subject.displayColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${subject.name}: ${_formatMinutes(minutes)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 科目易错点分布图
  Widget _buildSubjectChart(BuildContext context, Map<String, dynamic> data) {
    final subjects = data['subjects'] as List<Subject>;
    final mistakesBySubject = data['mistakesBySubject'] as Map<int, int>;

    if (subjects.isEmpty) return const SizedBox();

    final chartData = subjects
        .where((s) => (mistakesBySubject[s.id] ?? 0) > 0)
        .toList();

    if (chartData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📚 科目易错点分布',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📚 科目易错点分布',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 0,
                        sections: chartData.map((s) {
                          final count = mistakesBySubject[s.id] ?? 0;
                          return PieChartSectionData(
                            value: count.toDouble(),
                            color: s.displayColor,
                            radius: 60,
                            showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: chartData.map((s) {
                        final count = mistakesBySubject[s.id] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: s.displayColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${s.name}: $count',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 难度分布
  Widget _buildDifficultyChart(Map<String, dynamic> data) {
    final distribution = data['difficultyDistribution'] as Map<int, int>;
    final labels = ['简单', '较易', '中等', '较难', '困难'];
    final colors = [Colors.green, Colors.lightGreen, Colors.orange, Colors.deepOrange, Colors.red];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⭐ 难度分布',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...List.generate(5, (index) {
              final count = distribution[index + 1] ?? 0;
              final total = distribution.values.fold(0, (a, b) => a + b);
              final ratio = total > 0 ? count / total : 0.0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(labels[index], style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: colors[index].withOpacity(0.2),
                        color: colors[index],
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text('$count', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// 复习进度
  Widget _buildReviewProgress(Map<String, dynamic> data) {
    final reviewed = data['reviewedMistakes'] as int;
    final total = data['totalMistakes'] as int;
    final rate = data['reviewRate'] as double;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ 复习进度',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                LinearProgressIndicator(
                  value: rate,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.green,
                  minHeight: 20,
                  borderRadius: BorderRadius.circular(10),
                ),
                SizedBox(
                  height: 20,
                  child: Center(
                    child: Text(
                      '$reviewed / $total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              rate >= 0.8 ? '太棒了！继续保持 🎉' : 
              rate >= 0.5 ? '不错，还有提升空间 💪' : 
              '加油，坚持复习！📚',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h${m}m' : '${h}h';
    }
    return '${minutes}m';
  }
}
