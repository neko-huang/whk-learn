import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';

/// 课程表数据 Provider
final scheduleDataProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await DatabaseService.getSchedulesWithSubject();
});

/// 日历月份事项 Provider
final calendarMonthEventsProvider = FutureProvider.family<List<CalendarEvent>, DateTime>(
  (ref, monthDate) async {
    return await DatabaseService.getCalendarEventsByMonth(monthDate.year, monthDate.month);
  },
);

/// 日历日期事项 Provider
final calendarDateEventsProvider = FutureProvider.family<List<CalendarEvent>, DateTime>(
  (ref, date) async {
    return await DatabaseService.getCalendarEventsByDate(date);
  },
);

/// 课程表页面
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程表'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '课程表'),
            Tab(text: '日历'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ScheduleTab(),
          _CalendarTab(),
        ],
      ),
    );
  }
}

// ==================== 课程表 Tab ====================

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ScheduleContent();
  }
}

class _ScheduleContent extends ConsumerStatefulWidget {
  const _ScheduleContent();

  @override
  ConsumerState<_ScheduleContent> createState() => _ScheduleContentState();
}

class _ScheduleContentState extends ConsumerState<_ScheduleContent> {
  int _selectedWeekday = DateTime.now().weekday;

  static const _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(scheduleDataProvider);

    return Column(
      children: [
        _buildWeekdaySelector(),
        const Divider(height: 1),
        Expanded(
          child: schedules.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
            data: (data) => _buildScheduleList(data),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdaySelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(7, (index) {
          final weekday = index + 1;
          final isSelected = weekday == _selectedWeekday;
          final isToday = weekday == DateTime.now().weekday;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedWeekday = weekday),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : isToday
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdayNames[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.grey,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday && !isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isSelected
                                ? Colors.white
                                : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScheduleList(List<Map<String, dynamic>> data) {
    final filtered = data.where((item) {
      final schedule = item['schedule'] as ClassSchedule;
      return schedule.weekday == _selectedWeekday;
    }).toList();

    filtered.sort((a, b) {
      final timeA = (a['schedule'] as ClassSchedule).startTime;
      final timeB = (b['schedule'] as ClassSchedule).startTime;
      return timeA.compareTo(timeB);
    });

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '${_weekdayNames[_selectedWeekday - 1]}没有课程',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showAddScheduleDialog(),
              child: const Text('添加课程'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final schedule = item['schedule'] as ClassSchedule;
        final subject = item['subject'] as Subject?;
        return _buildScheduleCard(context, schedule, subject);
      },
    );
  }

  Widget _buildScheduleCard(BuildContext context, ClassSchedule schedule, Subject? subject) {
    final subjectColor = schedule.color != null && schedule.color!.isNotEmpty
        ? _parseColor(schedule.color!)
        : (subject?.displayColor ?? Colors.blue);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: subjectColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    schedule.startTime,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.endTime,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      subject?.name ?? '未知科目',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (schedule.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            schedule.location,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, schedule),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
                if (subject != null)
                  const PopupMenuItem(value: 'mistakes', child: Text('查看易错点')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action, ClassSchedule schedule) {
    switch (action) {
      case 'edit':
        _showEditScheduleDialog(schedule);
        break;
      case 'delete':
        _confirmDeleteSchedule(schedule);
        break;
      case 'mistakes':
        context.push('/mistakes?subjectId=${schedule.subjectId}');
        break;
    }
  }

  Future<void> _showAddScheduleDialog() async {
    final subjects = await DatabaseService.getVisibleSubjects();
    if (!mounted) return;

    _showScheduleDialog(
      title: '添加课程',
      subjects: subjects,
      onConfirm: (data) async {
        await DatabaseService.addSchedule(
          subjectId: data['subjectId'] as int,
          weekday: data['weekday'] as int,
          startTime: data['startTime'] as String,
          endTime: data['endTime'] as String,
          location: data['location'] as String? ?? '',
          color: data['color'] as String?,
        );
        ref.invalidate(scheduleDataProvider);
      },
    );
  }

  Future<void> _showEditScheduleDialog(ClassSchedule schedule) async {
    final subjects = await DatabaseService.getVisibleSubjects();
    if (!mounted) return;

    _showScheduleDialog(
      title: '编辑课程',
      subjects: subjects,
      initialData: {
        'subjectId': schedule.subjectId,
        'weekday': schedule.weekday,
        'startTime': schedule.startTime,
        'endTime': schedule.endTime,
        'location': schedule.location,
      },
      onConfirm: (data) async {
        await DatabaseService.updateSchedule(
          schedule.id,
          subjectId: data['subjectId'] as int?,
          weekday: data['weekday'] as int?,
          startTime: data['startTime'] as String?,
          endTime: data['endTime'] as String?,
          location: data['location'] as String?,
        );
        ref.invalidate(scheduleDataProvider);
      },
    );
  }

  void _showScheduleDialog({
    required String title,
    required List<Subject> subjects,
    Map<String, dynamic>? initialData,
    required Future<void> Function(Map<String, dynamic>) onConfirm,
  }) {
    int? selectedSubjectId = initialData?['subjectId'] as int?;
    int selectedWeekday = initialData?['weekday'] as int? ?? _selectedWeekday;
    TimeOfDay? startTime = initialData?['startTime'] != null
        ? _parseTime(initialData!['startTime'] as String)
        : null;
    TimeOfDay? endTime = initialData?['endTime'] != null
        ? _parseTime(initialData!['endTime'] as String)
        : null;
    String location = initialData?['location'] as String? ?? '';

    showModalBottomSheet(
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
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: selectedSubjectId,
                decoration: const InputDecoration(labelText: '选择科目'),
                items: subjects.map((s) {
                  return DropdownMenuItem(value: s.id, child: Text(s.name));
                }).toList(),
                onChanged: (v) => setModalState(() => selectedSubjectId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedWeekday,
                decoration: const InputDecoration(labelText: '星期'),
                items: List.generate(7, (i) {
                  return DropdownMenuItem(
                    value: i + 1,
                    child: Text(['周一', '周二', '周三', '周四', '周五', '周六', '周日'][i]),
                  );
                }),
                onChanged: (v) => setModalState(() {
                  if (v != null) {
                    selectedWeekday = v;
                    _selectedWeekday = v;
                  }
                }),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        startTime != null ? _formatTime(startTime!) : '开始时间',
                        style: TextStyle(color: startTime != null ? null : Colors.grey),
                      ),
                      subtitle: const Text('开始', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: startTime ?? const TimeOfDay(hour: 8, minute: 0),
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
                        endTime != null ? _formatTime(endTime!) : '结束时间',
                        style: TextStyle(color: endTime != null ? null : Colors.grey),
                      ),
                      subtitle: const Text('结束', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: endTime ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (t != null) setModalState(() => endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '地点（可选）',
                  hintText: '如：教学楼A301',
                ),
                onChanged: (v) => location = v,
                controller: TextEditingController(text: location),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedSubjectId == null || startTime == null || endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写完整信息')),
                      );
                      return;
                    }
                    onConfirm({
                      'subjectId': selectedSubjectId,
                      'weekday': selectedWeekday,
                      'startTime': _formatTime(startTime!),
                      'endTime': _formatTime(endTime!),
                      'location': location,
                    }).then((_) {
                      Navigator.pop(ctx);
                    });
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

  Future<void> _confirmDeleteSchedule(ClassSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这节课吗？'),
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
      await DatabaseService.deleteSchedule(schedule.id);
      ref.invalidate(scheduleDataProvider);
    }
  }

  TimeOfDay? _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _parseColor(String colorStr) {
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

// ==================== 日历 Tab ====================

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final monthEvents = ref.watch(calendarMonthEventsProvider(_focusedMonth));
    final dateEvents = ref.watch(calendarDateEventsProvider(_selectedDate));

    return Column(
      children: [
        _buildMonthHeader(),
        _buildWeekdayLabels(),
        _buildMonthGrid(monthEvents),
        const Divider(height: 1),
        _buildDateEventsList(dateEvents),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            }),
          ),
          Text(
            DateFormat('yyyy年M月').format(_focusedMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: _weekdayLabels.map((label) {
          return Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (label == '六' || label == '日')
                      ? Colors.orange.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(AsyncValue<List<CalendarEvent>> monthEvents) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: 1=Monday, 7=Sunday
    final startWeekday = firstDay.weekday; // 1-7
    final leadingBlanks = startWeekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    // 确定有事项的日期
    final Set<DateTime> eventDates = {};
    monthEvents.whenData((events) {
      for (final event in events) {
        if (event.eventType == 'one_time' && event.eventDate != null) {
          eventDates.add(DateTime(event.eventDate!.year, event.eventDate!.month, event.eventDate!.day));
        }
        // 长期安排每天都有，不需要标记
      }
    });

    // 收集长期安排的 weekday
    final Set<int> longTermWeekdays = {};
    monthEvents.whenData((events) {
      for (final event in events) {
        if (event.eventType == 'long_term' && event.repeatWeekday != null) {
          longTermWeekdays.add(event.repeatWeekday!);
        }
      }
    });

    return Expanded(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: rowCount * 7,
          itemBuilder: (context, index) {
            final dayNum = index - leadingBlanks + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(year, month, dayNum);
            final isToday = date == todayKey;
            final isSelected = date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;
            final hasEvent = eventDates.contains(date) || longTermWeekdays.contains(date.weekday);
            final isWeekend = date.weekday == 6 || date.weekday == 7;

            return GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : isToday
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                          : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday && !isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isWeekend
                                ? Colors.orange.shade700
                                : null,
                      ),
                    ),
                    if (hasEvent)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateEventsList(AsyncValue<List<CalendarEvent>> dateEvents) {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday
                      ? '今天 · ${DateFormat('M月d日').format(_selectedDate)}'
                      : DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(_selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: () => _showAddEventDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
          ),
          Expanded(
            child: dateEvents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (events) {
                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          '当天没有事项',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showAddEventDialog(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('添加事项'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return _buildEventCard(events[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final isLongTerm = event.eventType == 'long_term';
    final theme = Theme.of(context);

    return Dismissible(
      key: Key('calendar_event_${event.id}'),
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
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除「${event.title}」吗？'),
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
          await DatabaseService.deleteCalendarEvent(event.id);
          ref.invalidate(calendarDateEventsProvider(_selectedDate));
          ref.invalidate(calendarMonthEventsProvider(_focusedMonth));
          return true;
        }
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => _showEditEventDialog(event),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 类型图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLongTerm
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isLongTerm ? Icons.repeat : Icons.event,
                    color: isLongTerm ? Colors.blue : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (event.needReminder)
                            Icon(Icons.notifications_active,
                                size: 16, color: theme.colorScheme.primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatEventTime(event),
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      if (event.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatEventTime(CalendarEvent event) {
    if (event.eventType == 'long_term') {
      final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final weekday = event.repeatWeekday;
      final weekdayStr = weekday != null && weekday >= 1 && weekday <= 7
          ? weekdayNames[weekday - 1]
          : '未知';
      if (event.repeatStartTime != null && event.repeatStartTime!.isNotEmpty) {
        final endTime = event.repeatEndTime ?? '';
        return '$weekdayStr ${event.repeatStartTime}${endTime.isNotEmpty ? ' - $endTime' : ''}（长期）';
      }
      return '$weekdayStr（长期）';
    } else {
      if (event.eventTime != null && event.eventTime!.isNotEmpty) {
        return event.eventTime!;
      }
      return '全天';
    }
  }

  // ==================== 添加/编辑事项对话框 ====================

  Future<void> _showAddEventDialog() async {
    // 先选择类型
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择事项类型'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'one_time'),
            child: const ListTile(
              leading: Icon(Icons.event, color: Colors.orange),
              title: Text('时间点事项'),
              subtitle: Text('一次性事项，如考试、会议'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'long_term'),
            child: const ListTile(
              leading: Icon(Icons.repeat, color: Colors.blue),
              title: Text('长期安排'),
              subtitle: Text('重复性事项，如每周课程'),
            ),
          ),
        ],
      ),
    );
    if (type == null || !mounted) return;

    _showEventDialog(eventType: type, date: _selectedDate);
  }

  Future<void> _showEditEventDialog(CalendarEvent event) async {
    _showEventDialog(
      eventType: event.eventType,
      date: _selectedDate,
      event: event,
    );
  }

  void _showEventDialog({
    required String eventType,
    required DateTime date,
    CalendarEvent? event,
  }) {
    final titleController = TextEditingController(text: event?.title ?? '');
    final descController = TextEditingController(text: event?.description ?? '');
    final isLongTerm = eventType == 'long_term';

    // 时间点事项字段
    TimeOfDay? eventTimeOfDay;
    if (!isLongTerm && event?.eventTime != null && event!.eventTime!.isNotEmpty) {
      try {
        final parts = event.eventTime!.split(':');
        eventTimeOfDay = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    // 长期安排字段
    int selectedWeekday = event?.repeatWeekday ?? date.weekday;
    TimeOfDay? repeatStart;
    TimeOfDay? repeatEnd;
    if (isLongTerm && event?.repeatStartTime != null && event!.repeatStartTime!.isNotEmpty) {
      try {
        final parts = event.repeatStartTime!.split(':');
        repeatStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }
    if (isLongTerm && event?.repeatEndTime != null && event!.repeatEndTime!.isNotEmpty) {
      try {
        final parts = event.repeatEndTime!.split(':');
        repeatEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    // 提醒设置
    bool needReminder = event?.needReminder ?? false;
    int reminderMinutes = event?.reminderMinutesBefore ?? 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event == null
                      ? (isLongTerm ? '添加长期安排' : '添加时间点事项')
                      : (isLongTerm ? '编辑长期安排' : '编辑时间点事项'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '如：数学课、考试',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '添加描述信息...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                if (isLongTerm) ...[
                  DropdownButtonFormField<int>(
                    value: selectedWeekday,
                    decoration: const InputDecoration(labelText: '重复日'),
                    items: List.generate(7, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(['周一', '周二', '周三', '周四', '周五', '周六', '周日'][i]),
                      );
                    }),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedWeekday = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            repeatStart != null ? _formatTime(repeatStart!) : '开始时间',
                            style: TextStyle(color: repeatStart != null ? null : Colors.grey),
                          ),
                          subtitle: const Text('开始', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: repeatStart ?? const TimeOfDay(hour: 8, minute: 0),
                            );
                            if (t != null) setModalState(() => repeatStart = t);
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
                          title: Text(
                            repeatEnd != null ? _formatTime(repeatEnd!) : '结束时间',
                            style: TextStyle(color: repeatEnd != null ? null : Colors.grey),
                          ),
                          subtitle: const Text('结束', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: repeatEnd ?? const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (t != null) setModalState(() => repeatEnd = t);
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      eventTimeOfDay != null ? _formatTime(eventTimeOfDay!) : '选择时间',
                      style: TextStyle(color: eventTimeOfDay != null ? null : Colors.grey),
                    ),
                    subtitle: const Text('事件时间', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: eventTimeOfDay ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (t != null) setModalState(() => eventTimeOfDay = t);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                // 提醒设置
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('开启提醒'),
                  subtitle: Text(
                    needReminder ? '提前 $reminderMinutes 分钟提醒' : '不提醒',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: needReminder,
                  onChanged: (v) => setModalState(() {
                    needReminder = v;
                  }),
                ),
                if (needReminder) ...[
                  DropdownButtonFormField<int>(
                    value: reminderMinutes,
                    decoration: const InputDecoration(labelText: '提前提醒时间'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('准时提醒')),
                      DropdownMenuItem(value: 5, child: Text('5 分钟前')),
                      DropdownMenuItem(value: 10, child: Text('10 分钟前')),
                      DropdownMenuItem(value: 15, child: Text('15 分钟前')),
                      DropdownMenuItem(value: 30, child: Text('30 分钟前')),
                      DropdownMenuItem(value: 60, child: Text('1 小时前')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => reminderMinutes = v);
                    },
                  ),
                ],
                const SizedBox(height: 24),
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

                      if (event == null) {
                        // 新增
                        if (isLongTerm) {
                          await DatabaseService.addCalendarEvent(
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            eventType: 'long_term',
                            repeatWeekday: selectedWeekday,
                            repeatStartTime: repeatStart != null ? _formatTime(repeatStart!) : null,
                            repeatEndTime: repeatEnd != null ? _formatTime(repeatEnd!) : null,
                            needReminder: needReminder,
                            reminderMinutesBefore: reminderMinutes,
                          );
                        } else {
                          await DatabaseService.addCalendarEvent(
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            eventType: 'one_time',
                            eventDate: date,
                            eventTime: eventTimeOfDay != null ? _formatTime(eventTimeOfDay!) : null,
                            needReminder: needReminder,
                            reminderMinutesBefore: reminderMinutes,
                          );
                        }
                      } else {
                        // 更新
                        if (isLongTerm) {
                          await DatabaseService.updateCalendarEvent(
                            event.id,
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            repeatWeekday: selectedWeekday,
                            repeatStartTime: repeatStart != null ? _formatTime(repeatStart!) : null,
                            repeatEndTime: repeatEnd != null ? _formatTime(repeatEnd!) : null,
                            needReminder: needReminder,
                            reminderMinutesBefore: reminderMinutes,
                          );
                        } else {
                          await DatabaseService.updateCalendarEvent(
                            event.id,
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            eventDate: date,
                            eventTime: eventTimeOfDay != null ? _formatTime(eventTimeOfDay!) : null,
                            needReminder: needReminder,
                            reminderMinutesBefore: reminderMinutes,
                          );
                        }
                      }

                      ref.invalidate(calendarDateEventsProvider(_selectedDate));
                      ref.invalidate(calendarMonthEventsProvider(_focusedMonth));
                      Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
