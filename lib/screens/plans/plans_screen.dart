import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';

/// 学习计划数据 Provider（含动态完成时长）
final plansDataProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final plans = await DatabaseService.getStudyPlansWithSubject();
  // 动态计算每个计划的已完成分钟数
  final result = <Map<String, dynamic>>[];
  for (final item in plans) {
    final plan = item['plan'] as StudyPlan;
    final completedMinutes = await DatabaseService.getPlanCompletedMinutes(plan.id);
    result.add({
      ...item,
      'dynamicCompletedMinutes': completedMinutes,
    });
  }
  return result;
});

/// 学习计划页面
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statusTabs = [
    ('in_progress', '进行中'),
    ('pending', '待开始'),
    ('completed', '已完成'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习计划'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _statusTabs.map((t) => Tab(text: t.$2)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPlanDialog(),
          ),
        ],
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (data) => TabBarView(
          controller: _tabController,
          children: _statusTabs.map((tab) {
            final status = tab.$1;
            final filtered = data.where((item) {
              final plan = item['plan'] as StudyPlan;
              return plan.status == status;
            }).toList();

            if (filtered.isEmpty) {
              return _buildEmptyState(status);
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(plansDataProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final plan = item['plan'] as StudyPlan;
                  final subject = item['subject'] as Subject?;
                  return _buildPlanCard(context, plan, subject);
                },
              ),
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPlanDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(String status) {
    String message;
    IconData icon;
    switch (status) {
      case 'in_progress':
        message = '还没有进行中的计划';
        icon = Icons.play_circle_outline;
        break;
      case 'pending':
        message = '还没有待开始的计划';
        icon = Icons.schedule;
        break;
      case 'completed':
        message = '还没有已完成的计划';
        icon = Icons.check_circle_outline;
        break;
      default:
        message = '暂无计划';
        icon = Icons.note_add;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showAddPlanDialog(),
            child: const Text('创建计划'),
          ),
        ],
      ),
    );
  }

  /// 计划卡片
  Widget _buildPlanCard(BuildContext context, StudyPlan plan, Subject? subject) {
    // 使用动态计算数据
    final item = ref.read(plansDataProvider).value?.where((e) => (e['plan'] as StudyPlan).id == plan.id).firstOrNull;
    final completedMinutes = (item?['dynamicCompletedMinutes'] as int?) ?? plan.completedHours;
    final progress = plan.targetHours > 0
        ? (completedMinutes / (plan.targetHours * 60)).clamp(0.0, 1.0)
        : 0.0;
    final targetMinutes = plan.targetHours * 60;
    final dateFormat = DateFormat('MM/dd');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPlanDetail(plan, subject),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  if (subject != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: subject.displayColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      plan.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (plan.status == 'in_progress')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '进行中',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                      ),
                    ),
                ],
              ),
              if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  plan.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              // 日期范围
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormat.format(plan.startDate)} - ${dateFormat.format(plan.endDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (subject != null) ...[
                    const Spacer(),
                    Text(
                      subject.name,
                      style: TextStyle(fontSize: 12, color: subject.displayColor),
                    ),
                  ],
                ],
              ),
              // 进度条
              if (plan.targetHours > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          color: subject?.displayColor ?? Theme.of(context).colorScheme.primary,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatMinutes(completedMinutes)}/${_formatMinutes(targetMinutes)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化分钟为 x小时x分钟
  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h${mins}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  /// 显示计划详情
  void _showPlanDetail(StudyPlan plan, Subject? subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PlanDetailSheet(plan: plan, subject: subject),
    ).then((_) => ref.invalidate(plansDataProvider));
  }

  /// 添加计划弹窗
  Future<void> _showAddPlanDialog() async {
    final subjects = await DatabaseService.getVisibleSubjects();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditPlanSheet(subjects: subjects),
    ).then((_) => ref.invalidate(plansDataProvider));
  }


}

/// 计划详情弹窗
class _PlanDetailSheet extends ConsumerWidget {
  final StudyPlan plan;
  final Subject? subject;

  const _PlanDetailSheet({required this.plan, this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) => FutureBuilder(
        future: DatabaseService.getPomodoroRecordsByPlan(plan.id),
        builder: (context, snapshot) {
          final records = snapshot.data ?? [];
          final totalMinutes = records
              .where((r) => r.type == 'focus' && r.completed)
              .fold<int>(0, (sum, r) => sum + r.duration);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.pop(context);
                          final subjects = await DatabaseService.getVisibleSubjects();
                          if (context.mounted) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (ctx) => _AddEditPlanSheet(subjects: subjects, editPlan: plan),
                            ).then((_) => ref.invalidate(plansDataProvider));
                          }
                        } else if (value == 'delete') {
                          _confirmDelete(context, ref);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Text('编辑计划')),
                        const PopupMenuItem(value: 'delete', child: Text('删除计划')),
                      ],
                    ),
                  ],
                ),
                if (plan.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(plan.description, style: TextStyle(color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 20),
                // 统计
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('已完成', _formatMinutes(totalMinutes), Colors.green),
                    _buildStat('目标', _formatMinutes(plan.targetHours * 60), Colors.blue),
                    _buildStat('番茄数', '${records.where((r) => r.type == 'focus' && r.completed).length}', Colors.orange),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  '番茄钟记录',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('暂无记录', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final dateStr = DateFormat('MM/dd HH:mm').format(record.startTime);
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            record.type == 'focus' ? Icons.timer : Icons.coffee,
                            size: 20,
                            color: record.type == 'focus' ? Colors.red : Colors.green,
                          ),
                          title: Text(
                            '${record.duration}分钟 - ${record.type == 'focus' ? '专注' : '休息'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                          trailing: record.completed
                              ? const Icon(Icons.check_circle, size: 18, color: Colors.green)
                              : const Icon(Icons.cancel, size: 18, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (plan.status == 'pending')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await DatabaseService.updateStudyPlan(plan.id, status: 'in_progress');
                              if (context.mounted) Navigator.pop(context);
                              ref.invalidate(plansDataProvider);
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('开始执行'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (plan.status == 'in_progress')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await DatabaseService.updateStudyPlan(plan.id, status: 'completed');
                              if (context.mounted) Navigator.pop(context);
                              ref.invalidate(plansDataProvider);
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('标记完成'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (plan.status == 'in_progress' || plan.status == 'pending')
                        const SizedBox(width: 12),
                      if (plan.status == 'completed')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await DatabaseService.updateStudyPlan(plan.id, status: 'in_progress');
                              if (context.mounted) Navigator.pop(context);
                              ref.invalidate(plansDataProvider);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新开始'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return mins > 0 ? '${hours}h${mins}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个学习计划吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.deleteStudyPlan(plan.id);
      ref.invalidate(plansDataProvider);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

/// 添加/编辑计划弹窗
class _AddEditPlanSheet extends StatefulWidget {
  final List<Subject> subjects;
  final StudyPlan? editPlan;

  const _AddEditPlanSheet({required this.subjects, this.editPlan});

  @override
  State<_AddEditPlanSheet> createState() => _AddEditPlanSheetState();
}

class _AddEditPlanSheetState extends State<_AddEditPlanSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  int? _selectedSubjectId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  int _targetHours = 10;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.editPlan?.title ?? '');
    _descriptionController = TextEditingController(text: widget.editPlan?.description ?? '');
    _selectedSubjectId = widget.editPlan?.subjectId;
    _startDate = widget.editPlan?.startDate ?? DateTime.now();
    _endDate = widget.editPlan?.endDate ?? DateTime.now().add(const Duration(days: 7));
    _targetHours = widget.editPlan?.targetHours ?? 10;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editPlan != null ? '编辑计划' : '新建计划',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '计划名称',
                hintText: '如：期末复习计划',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                hintText: '计划详细说明',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // 科目选择
            DropdownButtonFormField<int>(
              value: _selectedSubjectId,
              decoration: const InputDecoration(labelText: '关联科目（可选）'),
              items: [
                const DropdownMenuItem(value: null, child: Text('不关联')),
                ...widget.subjects.map((s) {
                  return DropdownMenuItem(value: s.id, child: Text(s.name));
                }),
              ],
              onChanged: (v) => setState(() => _selectedSubjectId = v),
            ),
            const SizedBox(height: 16),
            // 日期范围
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(dateFormat.format(_startDate)),
                    subtitle: const Text('开始日期', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setState(() => _startDate = date);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward, size: 20),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(dateFormat.format(_endDate)),
                    subtitle: const Text('结束日期', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2030),
                      );
                      if (date != null) setState(() => _endDate = date);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 目标时长
            Row(
              children: [
                const Text('目标时长: ', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  onPressed: _targetHours > 1
                      ? () => setState(() => _targetHours--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_targetHours 小时',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => setState(() => _targetHours++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入计划名称')),
      );
      return;
    }

    if (widget.editPlan != null) {
      await DatabaseService.updateStudyPlan(
        widget.editPlan!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        subjectId: _selectedSubjectId,
        startDate: _startDate,
        endDate: _endDate,
        targetHours: _targetHours,
      );
    } else {
      await DatabaseService.addStudyPlan(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        subjectId: _selectedSubjectId,
        startDate: _startDate,
        endDate: _endDate,
        targetHours: _targetHours,
        status: 'pending',
      );
    }

    Navigator.pop(context);
  }
}
