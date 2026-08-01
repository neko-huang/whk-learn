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

  return {
    'subjects': subjects,
    'mistakesBySubject': mistakesBySubject,
    'reviewedBySubject': reviewedBySubject,
    'dailyTrend': dailyTrend,
    'totalMistakes': totalMistakes,
    'reviewedMistakes': reviewedMistakes,
    'reviewRate': reviewRate,
    'difficultyDistribution': difficultyDistribution,
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
                // 总览卡片
                _buildOverviewCard(data),
                const SizedBox(height: 20),

                // 7天趋势图
                _buildTrendChart(data),
                const SizedBox(height: 20),

                // 科目分布
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
              '📊 学习总览',
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

  /// 7天趋势图
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
              '📈 最近7天',
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

  /// 科目分布图
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
                '📚 科目分布',
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
              '📚 科目分布',
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
}


