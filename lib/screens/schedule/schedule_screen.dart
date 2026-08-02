import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/database.dart';
import '../../services/database_service.dart';

/// 课程表数据 Provider
final scheduleDataProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await DatabaseService.getSchedulesWithSubject();
});

/// 课程表页面
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: '日历',
            onPressed: () => context.push('/calendar'),
          ),
        ],
      ),
      body: const _ScheduleContent(),
    );
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