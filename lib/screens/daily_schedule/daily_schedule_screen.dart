import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column, Row;
import '../../models/database.dart';
import '../../services/database_service.dart';

/// 理想时间表 Provider（按日期）
final idealSchedulesProvider = FutureProvider.family<List<DailySchedule>, DateTime>(
  (ref, date) async => await DatabaseService.getIdealSchedulesByDate(date),
);

/// 实际时间表 Provider（按日期）
final actualSchedulesProvider = FutureProvider.family<List<DailySchedule>, DateTime>(
  (ref, date) async => await DatabaseService.getActualSchedulesByDate(date),
);

/// 日程页面 - 理想时间表 / 实际时间表 两栏
class DailyScheduleScreen extends ConsumerStatefulWidget {
  const DailyScheduleScreen({super.key});

  @override
  ConsumerState<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends ConsumerState<DailyScheduleScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _invalidateAll() {
    ref.invalidate(idealSchedulesProvider(_selectedDate));
    ref.invalidate(actualSchedulesProvider(_selectedDate));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日程'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🌟 理想时间表'),
            Tab(text: '📅 实际时间表'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIdealTab(),
                _buildActualTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousDay,
          ),
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
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextDay,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        if (_tabController.index == 0) {
          return FloatingActionButton(
            onPressed: () => _showIdealEditDialog(null),
            child: const Icon(Icons.add),
          );
        } else {
          return FloatingActionButton(
            onPressed: () => _showActualEditDialog(null),
            child: const Icon(Icons.add),
          );
        }
      },
    );
  }

  // ==================== 理想时间表 Tab ====================

  Widget _buildIdealTab() {
    final idealAsync = ref.watch(idealSchedulesProvider(_selectedDate));

    return idealAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (ideals) {
        if (ideals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 64, color: Colors.amber.shade200),
                const SizedBox(height: 16),
                const Text('还没有理想安排，点击 + 添加',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, size: 24, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        '添加理想安排后，可一键迁移到实际时间表',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ideals.length,
          itemBuilder: (context, index) =>
              _buildIdealCard(ideals[index], index),
        );
      },
    );
  }

  Widget _buildIdealCard(DailySchedule schedule, int index) {
    final color = _getColorForIndex(index);
    final theme = Theme.of(context);

    return Dismissible(
      key: Key('ideal_${schedule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await _confirmDeleteIdeal(schedule),
      onDismissed: (_) {
        _invalidateAll();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(
            children: [
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
              Container(
                width: 70,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(schedule.startTime,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(schedule.endTime,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.grey.shade200,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(schedule.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if (schedule.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(schedule.note,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ),
              // 更多操作
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showIdealEditDialog(schedule);
                      break;
                    case 'delete':
                      _confirmDeleteIdeal(schedule);
                      break;
                    case 'migrate':
                      _migrateToActual(schedule);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'migrate', child: Text('迁移到实际')),
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteIdeal(DailySchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除理想安排「${schedule.title}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.deleteIdealSchedule(schedule.id);
      ref.invalidate(idealSchedulesProvider(_selectedDate));
      return true;
    }
    return false;
  }


  /// 将理想安排迁移到实际时间表
  Future<void> _migrateToActual(DailySchedule schedule) async {
    try {
      await _addActualSchedule(
        schedule.startTime,
        schedule.endTime,
        schedule.title,
        schedule.note,
      );
      ref.invalidate(idealSchedulesProvider(_selectedDate));
      ref.invalidate(actualSchedulesProvider(_selectedDate));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已迁移到实际时间表')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('迁移失败: $e')),
        );
      }
    }
  }

  // ==================== 实际时间表 Tab ====================

  Widget _buildActualTab() {
    final actualAsync = ref.watch(actualSchedulesProvider(_selectedDate));

    return actualAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (actuals) {
        if (actuals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  _isToday ? '今天还没有安排' : '这天没有安排',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }
        return _buildActualList(actuals);
      },
    );
  }

  Widget _buildActualList(List<DailySchedule> actuals) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: actuals.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex -= 1;
        final newOrder = List<DailySchedule>.from(actuals);
        final item = newOrder.removeAt(oldIndex);
        newOrder.insert(newIndex, item);
        final orderedIds = newOrder.map((s) => s.id).toList();
        DatabaseService.reorderActualSchedules(orderedIds);
        ref.invalidate(actualSchedulesProvider(_selectedDate));
      },
      itemBuilder: (context, index) {
        final schedule = actuals[index];
        return _buildActualCard(schedule, index);
      },
    );
  }

  Widget _buildActualCard(DailySchedule schedule, int index) {
    final isDone = schedule.isCompleted;
    final theme = Theme.of(context);

    return Dismissible(
      key: Key('actual_${schedule.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await DatabaseService.deleteActualSchedule(schedule.id);
        ref.invalidate(actualSchedulesProvider(_selectedDate));
        return true;
      },
      child: Card(
        key: ValueKey(schedule.id),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () => _showActualEditDialog(schedule),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                // 勾选框
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Checkbox(
                    value: isDone,
                    onChanged: (_) async {
                      await DatabaseService
                          .toggleActualScheduleCompleted(schedule.id);
                      ref.invalidate(
                          actualSchedulesProvider(_selectedDate));
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                // 时间区域
                InkWell(
                  onTap: () =>
                      _quickEditTime(schedule, isStart: true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        Text(
                          schedule.startTime,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.grey : null,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          schedule.endTime,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDone
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.shade200,
                ),
                // 标题 + 备注
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 8),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDone
                                ? Colors.grey.shade500
                                : null,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (schedule.note.isNotEmpty)
                          Text(
                            schedule.note,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDone
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                // 拖拽手柄
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle,
                        color: theme.disabledColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _quickEditTime(
      DailySchedule schedule, {required bool isStart}) async {
    final initial = _parseTime(isStart ? schedule.startTime : schedule.endTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (isStart) {
      await DatabaseService.updateActualSchedule(
          schedule.id, startTime: formatted);
    } else {
      await DatabaseService.updateActualSchedule(
          schedule.id, endTime: formatted);
    }
    ref.invalidate(actualSchedulesProvider(_selectedDate));
  }

  // ==================== 编辑对话框 ====================

  Future<void> _showIdealEditDialog(DailySchedule? schedule) async {
    final titleController = TextEditingController(text: schedule?.title ?? '');
    final noteController = TextEditingController(text: schedule?.note ?? '');
    TimeOfDay startTime =
        schedule != null ? _parseTime(schedule.startTime) : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime =
        schedule != null ? _parseTime(schedule.endTime) : const TimeOfDay(hour: 9, minute: 0);

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(schedule == null ? '添加理想安排' : '编辑理想安排',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '如：晨读英语',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_formatTime(startTime),
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.primary)),
                      subtitle: const Text('开始',
                          style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t =
                            await showTimePicker(context: ctx, initialTime: startTime);
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
                      title: Text(_formatTime(endTime),
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.primary)),
                      subtitle: const Text('结束',
                          style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t =
                            await showTimePicker(context: ctx, initialTime: endTime);
                        if (t != null) setModalState(() => endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '添加备注信息...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请填写标题')));
                      return;
                    }
                    final startStr = _formatTime(startTime);
                    final endStr = _formatTime(endTime);

                    if (schedule == null) {
                      await DatabaseService.addIdealSchedule(
                        date: _selectedDate,
                        startTime: startStr,
                        endTime: endStr,
                        title: titleController.text.trim(),
                        note: noteController.text.trim(),
                      );
                    } else {
                      await DatabaseService.updateIdealSchedule(
                        schedule.id,
                        startTime: startStr,
                        endTime: endStr,
                        title: titleController.text.trim(),
                        note: noteController.text.trim(),
                      );
                    }
                    ref.invalidate(idealSchedulesProvider(_selectedDate));
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

  Future<void> _showActualEditDialog(DailySchedule? schedule) async {
    final titleController = TextEditingController(text: schedule?.title ?? '');
    final noteController = TextEditingController(text: schedule?.note ?? '');
    TimeOfDay startTime =
        schedule != null ? _parseTime(schedule.startTime) : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime =
        schedule != null ? _parseTime(schedule.endTime) : const TimeOfDay(hour: 9, minute: 0);

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(schedule == null ? '添加实际安排' : '编辑实际安排',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '如：复习数学第三章',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_formatTime(startTime),
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.primary)),
                      subtitle: const Text('开始',
                          style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t =
                            await showTimePicker(context: ctx, initialTime: startTime);
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
                      title: Text(_formatTime(endTime),
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.primary)),
                      subtitle: const Text('结束',
                          style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t =
                            await showTimePicker(context: ctx, initialTime: endTime);
                        if (t != null) setModalState(() => endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '添加备注信息...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请填写标题')));
                      return;
                    }
                    final startStr = _formatTime(startTime);
                    final endStr = _formatTime(endTime);

                    if (schedule == null) {
                      await _addActualSchedule(
                        startStr, endStr,
                        titleController.text.trim(),
                        noteController.text.trim(),
                      );
                    } else {
                      await DatabaseService.updateActualSchedule(
                        schedule.id,
                        startTime: startStr,
                        endTime: endStr,
                        title: titleController.text.trim(),
                        note: noteController.text.trim(),
                      );
                    }
                    ref.invalidate(actualSchedulesProvider(_selectedDate));
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

  /// 添加一条实际安排
  Future<void> _addActualSchedule(
      String startTime, String endTime, String title, String note) async {
    final db = await DatabaseService.database;
    final normalizedDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    final existing = await (db.select(db.dailySchedules)
      ..where((t) =>
          t.date.equals(normalizedDate) & t.scheduleType.equals('actual'))
    ).get();
    final nextOrder = existing.isEmpty
        ? 0
        : existing
                .map((e) => e.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;

    await db.into(db.dailySchedules).insert(
      DailySchedulesCompanion.insert(
        date: normalizedDate,
        startTime: startTime,
        endTime: endTime,
        title: title,
        note: Value(note),
        sortOrder: Value(nextOrder),
        scheduleType: const Value('actual'),
      ),
    );
  }

  // ==================== 工具方法 ====================

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
