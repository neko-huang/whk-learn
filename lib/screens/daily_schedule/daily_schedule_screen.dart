import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/database.dart';
import '../../services/database_service.dart';

/// 每日日程 Provider
final dailySchedulesProvider = FutureProvider.family<List<DailySchedule>, DateTime>(
  (ref, date) async {
    return await DatabaseService.getDailySchedulesByDate(date);
  },
);

/// 日程页面
class DailyScheduleScreen extends ConsumerStatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  ConsumerState<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends ConsumerState<DailyScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(dailySchedulesProvider(_selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('日程'),
      ),
      body: Column(
        children: [
          // 日期选择栏
          _buildDateSelector(),
          const Divider(height: 1),
          // 日程列表
          Expanded(
            child: schedules.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (data) => _buildScheduleList(data),
            ),
          ),
        ],
      ),
      floatingActionButton: _isToday
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 上一天
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousDay,
          ),
          // 日期显示
          GestureDetector(
            onTap: _pickDate,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text(
                  _isToday
                      ? '今天 · ${DateFormat('M月d日').format(_selectedDate)}'
                      : '${DateFormat('yyyy年M月d日').format(_selectedDate)} '
                          '${_weekdays[_selectedDate.weekday - 1]}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
          // 下一天
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextDay,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList(List<DailySchedule> data) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _isToday ? '今天还没有安排' : '这天没有安排',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_isToday)
              TextButton(
                onPressed: () => _showAddDialog(),
                child: const Text('添加安排'),
              )
            else
              Text(
                '历史日程仅可查看',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final schedule = data[index];
        return _buildScheduleCard(schedule, index);
      },
    );
  }

  Widget _buildScheduleCard(DailySchedule schedule, int index) {
    final color = _getColorForIndex(index);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // 左侧色条
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // 时间列
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    schedule.startTime,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.endTime,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // 分隔线
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.grey.shade200,
            ),
            // 内容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      schedule.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (schedule.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        schedule.note,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 操作按钮（仅今天可编辑）
            if (_isToday)
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, schedule),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action, DailySchedule schedule) {
    switch (action) {
      case 'edit':
        _showEditDialog(schedule);
        break;
      case 'delete':
        _confirmDelete(schedule);
        break;
    }
  }

  Future<void> _showAddDialog() async {
    _showEditDialog(null);
  }

  Future<void> _showEditDialog(DailySchedule? schedule) async {
    final titleController = TextEditingController(text: schedule?.title ?? '');
    final noteController = TextEditingController(text: schedule?.note ?? '');
    TimeOfDay startTime = schedule != null ? _parseTime(schedule.startTime) : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = schedule != null ? _parseTime(schedule.endTime) : const TimeOfDay(hour: 9, minute: 0);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                schedule == null ? '添加安排' : '编辑安排',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // 标题
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '如：复习数学第三章',
                ),
              ),
              const SizedBox(height: 16),
              // 时间段
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _formatTime(startTime),
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      subtitle: const Text('开始', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: startTime,
                        );
                        if (t != null) setModalState(() => startTime = t);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 20),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _formatTime(endTime),
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      subtitle: const Text('结束', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: endTime,
                        );
                        if (t != null) setModalState(() => endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 备注
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '添加备注信息...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写标题')),
                      );
                      return;
                    }

                    final startStr = _formatTime(startTime);
                    final endStr = _formatTime(endTime);

                    if (schedule == null) {
                      // 新增
                      await DatabaseService.addDailySchedule(
                        date: _selectedDate,
                        startTime: startStr,
                        endTime: endStr,
                        title: titleController.text.trim(),
                        note: noteController.text.trim(),
                      );
                    } else {
                      // 编辑
                      await DatabaseService.updateDailySchedule(
                        schedule.id,
                        startTime: startStr,
                        endTime: endStr,
                        title: titleController.text.trim(),
                        note: noteController.text.trim(),
                      );
                    }

                    ref.invalidate(dailySchedulesProvider(_selectedDate));
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(DailySchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${schedule.title}」吗？'),
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
      await DatabaseService.deleteDailySchedule(schedule.id);
      ref.invalidate(dailySchedulesProvider(_selectedDate));
    }
  }

  TimeOfDay _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }
}
