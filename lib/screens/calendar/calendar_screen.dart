import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/database.dart';
import '../../services/database_service.dart';

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

/// 日历页面（独立页面，从课程表分离）
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final monthEvents = ref.watch(calendarMonthEventsProvider(_focusedMonth));
    final dateEvents = ref.watch(calendarDateEventsProvider(_selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildWeekdayLabels(),
          // 月历网格：使用 SizedBox 固定高度，避免 Expanded 约束冲突
          SizedBox(
            key: ValueKey('grid_${_focusedMonth.millisecondsSinceEpoch}'),
            height: _calcGridHeight(),
            child: _buildMonthGrid(monthEvents),
          ),
          const Divider(height: 1),
          Expanded(
            key: ValueKey('events_${_selectedDate.millisecondsSinceEpoch}'),
            child: _buildDateEventsList(dateEvents),
          ),
        ],
      ),
    );
  }

  /// 计算当前月历网格所需高度
  double _calcGridHeight() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday;
    final leadingBlanks = startWeekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    const rowHeight = 56.0;
    return rowCount * rowHeight;
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

  /// 使用 LayoutBuilder + 手动行列布局渲染月历网格
  Widget _buildMonthGrid(AsyncValue<List<CalendarEvent>> monthEvents) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;

    // 无论数据加载状态如何，网格都正常渲染
    // 提取三类信息：一次性事项日期、长期安排 weekday、时间段范围详情
    final oneTimeDates = _extractOneTimeEventDates(monthEvents, year, month);
    final longTermWeekdays = _extractLongTermWeekdays(monthEvents);
    final dateRangeInfo = _extractDateRangeInfo(monthEvents);

    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday;
    final leadingBlanks = startWeekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    const rowHeight = 56.0;
    final gridHeight = rowCount * rowHeight;

    return SizedBox(
      height: gridHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 去掉 margin 占用，精确计算每个格子的可用宽度
            final cellWidth = (constraints.maxWidth / 7) - 4.0; // 4px = 左右各2px margin
            final safeCellWidth = cellWidth > 0 ? cellWidth : 50.0;
            return Column(
              children: List.generate(rowCount, (rowIndex) {
                return SizedBox(
                  height: rowHeight,
                  child: Row(
                    children: List.generate(7, (colIndex) {
                      final cellIndex = rowIndex * 7 + colIndex;
                      final dayNum = cellIndex - leadingBlanks + 1;

                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return SizedBox(width: safeCellWidth + 4);
                      }

                      final date = DateTime(year, month, dayNum);
                      final isToday = date == todayKey;
                      final isSelected = date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;
                      final isWeekend = date.weekday == 6 || date.weekday == 7;

                      final hasOneTime = oneTimeDates.contains(date);
                      final hasLongTerm = longTermWeekdays.contains(date.weekday);
                      final drInfo = dateRangeInfo[date];

                      return GestureDetector(
                        onTap: () => _onDayTap(date),
                        child: Container(
                          width: safeCellWidth,
                          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : isToday
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                    : null,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              // 主内容：日期数字 + 彩色圆点
                              Positioned.fill(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$dayNum',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isToday || isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Colors.white
                                            : isWeekend
                                                ? Colors.orange.shade700
                                                : null,
                                      ),
                                    ),
                                    // 类别圆点行
                                    if (hasOneTime || hasLongTerm)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (hasOneTime)
                                              _buildCategoryDot(
                                                isSelected ? Colors.white : Colors.orange.shade500,
                                              ),
                                            if (hasOneTime && hasLongTerm)
                                              const SizedBox(width: 3),
                                            if (hasLongTerm)
                                              _buildCategoryDot(
                                                isSelected ? Colors.white : Colors.blue.shade400,
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // 绿色时间段日程底条
                              if (drInfo != null)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 2,
                                  child: Center(
                                    child: Container(
                                      height: 4,
                                      width: safeCellWidth - 4,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.8)
                                            : Colors.green.shade400,
                                        borderRadius: BorderRadius.horizontal(
                                          left: Radius.circular(
                                            drInfo == 'start' || drInfo == 'single' ? 2 : 0,
                                          ),
                                          right: Radius.circular(
                                            drInfo == 'end' || drInfo == 'single' ? 2 : 0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  /// 构建类别小圆点（4px 直径）
  Widget _buildCategoryDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  /// 提取有时间点事项的日期集合（🟠 橙色圆点）
  Set<DateTime> _extractOneTimeEventDates(AsyncValue<List<CalendarEvent>> monthEvents, int year, int month) {
    final Set<DateTime> dates = {};
    monthEvents.whenData((events) {
      for (final event in events) {
        if (event.eventType == 'one_time' && event.eventDate != null) {
          dates.add(DateTime(
            event.eventDate!.year, event.eventDate!.month, event.eventDate!.day,
          ));
        }
      }
    });
    return dates;
  }

  /// 提取长期安排的 weekday 集合（🔵 蓝色圆点）
  Set<int> _extractLongTermWeekdays(AsyncValue<List<CalendarEvent>> monthEvents) {
    final Set<int> weekdays = {};
    monthEvents.whenData((events) {
      for (final event in events) {
        if (event.eventType == 'long_term' && event.repeatWeekday != null) {
          weekdays.add(event.repeatWeekday!);
        }
      }
    });
    return weekdays;
  }

  /// 提取时间段日程范围信息（🟢 绿色底条）
  /// 返回 Map<DateTime, String>，value 为 'start'/'middle'/'end'/'single'
  Map<DateTime, String> _extractDateRangeInfo(AsyncValue<List<CalendarEvent>> monthEvents) {
    final Map<DateTime, String> info = {};
    monthEvents.whenData((events) {
      for (final event in events) {
        if (event.eventType == 'date_range' &&
            event.rangeStartDate != null &&
            event.rangeEndDate != null) {
          final start = DateTime(
            event.rangeStartDate!.year, event.rangeStartDate!.month, event.rangeStartDate!.day,
          );
          final end = DateTime(
            event.rangeEndDate!.year, event.rangeEndDate!.month, event.rangeEndDate!.day,
          );
          var d = DateTime(start.year, start.month, start.day);

          if (start == end) {
            // 单天范围
            info[d] = 'single';
          } else {
            // 开始日
            info[d] = 'start';
            d = d.add(const Duration(days: 1));
            // 中间日
            while (d.isBefore(end)) {
              info[d] = 'middle';
              d = d.add(const Duration(days: 1));
            }
            // 结束日
            info[end] = 'end';
          }
        }
      }
    });
    return info;
  }

  /// 点击某天时的处理，确保安全
  void _onDayTap(DateTime date) {
    if (!mounted) return;
    setState(() {
      _selectedDate = date;
    });
  }

  Widget _buildDateEventsList(AsyncValue<List<CalendarEvent>> dateEvents) {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Column(
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
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('加载失败', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        ref.invalidate(calendarDateEventsProvider(_selectedDate));
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
            data: (events) {
              if (events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('当天没有事项', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                itemBuilder: (context, index) => _buildEventCard(events[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final isLongTerm = event.eventType == 'long_term';
    final isDateRange = event.eventType == 'date_range';
    final theme = Theme.of(context);

    // 根据类型设置图标和颜色
    IconData iconData;
    Color iconBgColor;
    Color iconColor;
    if (isDateRange) {
      iconData = Icons.date_range;
      iconBgColor = Colors.green.withOpacity(0.1);
      iconColor = Colors.green;
    } else if (isLongTerm) {
      iconData = Icons.repeat;
      iconBgColor = Colors.blue.withOpacity(0.1);
      iconColor = Colors.blue;
    } else {
      iconData = Icons.event;
      iconBgColor = Colors.orange.withOpacity(0.1);
      iconColor = Colors.orange;
    }

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
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: iconColor, size: 20),
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
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (event.needReminder)
                            Icon(Icons.notifications_active, size: 16, color: theme.colorScheme.primary),
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
          ? weekdayNames[weekday - 1] : '未知';
      if (event.repeatStartTime != null && event.repeatStartTime!.isNotEmpty) {
        final endTime = event.repeatEndTime ?? '';
        return '$weekdayStr ${event.repeatStartTime}${endTime.isNotEmpty ? ' - $endTime' : ''}（长期）';
      }
      return '$weekdayStr（长期）';
    } else if (event.eventType == 'date_range') {
      final start = event.rangeStartDate;
      final end = event.rangeEndDate;
      if (start != null && end != null) {
        final startStr = DateFormat('M月d日').format(start);
        final endStr = DateFormat('M月d日').format(end);
        final suffix = (event.repeatStartTime != null && event.repeatStartTime!.isNotEmpty)
            ? ' ${event.repeatStartTime}${(event.repeatEndTime != null && event.repeatEndTime!.isNotEmpty) ? '-${event.repeatEndTime}' : ''}'
            : '';
        return '$startStr - $endStr$suffix';
      }
      return '时间段日程';
    } else {
      if (event.eventTime != null && event.eventTime!.isNotEmpty) {
        return event.eventTime!;
      }
      return '全天';
    }
  }

  // ==================== 添加/编辑事项对话框 ====================

  Future<void> _showAddEventDialog() async {
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
            onPressed: () => Navigator.pop(ctx, 'date_range'),
            child: const ListTile(
              leading: Icon(Icons.date_range, color: Colors.green),
              title: Text('时间段日程'),
              subtitle: Text('跨越多天的安排，如假期课程'),
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
    _showEventDialog(eventType: event.eventType, date: _selectedDate, event: event);
  }

  void _showEventDialog({
    required String eventType,
    required DateTime date,
    CalendarEvent? event,
  }) {
    final titleController = TextEditingController(text: event?.title ?? '');
    final descController = TextEditingController(text: event?.description ?? '');
    final isLongTerm = eventType == 'long_term';
    final isDateRange = eventType == 'date_range';

    // 时间点事项字段
    TimeOfDay? eventTimeOfDay;
    if (!isLongTerm && !isDateRange && event?.eventTime != null && event!.eventTime!.isNotEmpty) {
      try {
        final parts = event.eventTime!.split(':');
        eventTimeOfDay = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    // 长期安排字段
    int selectedWeekday = event?.repeatWeekday ?? date.weekday;
    TimeOfDay? repeatStart;
    TimeOfDay? repeatEnd;
    if ((isLongTerm || isDateRange) && event?.repeatStartTime != null && event!.repeatStartTime!.isNotEmpty) {
      try {
        final parts = event.repeatStartTime!.split(':');
        repeatStart = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }
    if ((isLongTerm || isDateRange) && event?.repeatEndTime != null && event!.repeatEndTime!.isNotEmpty) {
      try {
        final parts = event.repeatEndTime!.split(':');
        repeatEnd = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }

    // 时间段日程字段
    DateTime rangeStart = event?.rangeStartDate ?? date;
    DateTime rangeEnd = event?.rangeEndDate ?? date;

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
                      ? (isLongTerm ? '添加长期安排' : isDateRange ? '添加时间段日程' : '添加时间点事项')
                      : (isLongTerm ? '编辑长期安排' : isDateRange ? '编辑时间段日程' : '编辑时间点事项'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '标题', hintText: '如：数学课、考试'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '描述（可选）', hintText: '添加描述信息...'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                if (isDateRange) ...[
                  // 时间段日程：开始日期 + 结束日期
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('yyyy年M月d日').format(rangeStart)),
                    subtitle: const Text('开始日期', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: rangeStart,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setModalState(() => rangeStart = picked);
                        if (rangeEnd.isBefore(rangeStart)) {
                          rangeEnd = rangeStart;
                        }
                      }
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.arrow_downward, size: 20),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('yyyy年M月d日').format(rangeEnd)),
                    subtitle: const Text('结束日期', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: rangeEnd,
                        firstDate: rangeStart,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setModalState(() => rangeEnd = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  // 可选的每日时间段
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            repeatStart != null ? _formatTime(repeatStart!) : '每日开始时间',
                            style: TextStyle(color: repeatStart != null ? null : Colors.grey),
                          ),
                          subtitle: const Text('开始', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx, initialTime: repeatStart ?? const TimeOfDay(hour: 8, minute: 0),
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
                            repeatEnd != null ? _formatTime(repeatEnd!) : '每日结束时间',
                            style: TextStyle(color: repeatEnd != null ? null : Colors.grey),
                          ),
                          subtitle: const Text('结束', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final t = await showTimePicker(
                              context: ctx, initialTime: repeatEnd ?? const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (t != null) setModalState(() => repeatEnd = t);
                          },
                        ),
                      ),
                    ],
                  ),
                ] else if (isLongTerm) ...[
                  DropdownButtonFormField<int>(
                    value: selectedWeekday,
                    decoration: const InputDecoration(labelText: '重复日'),
                    items: List.generate(7, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(['周一', '周二', '周三', '周四', '周五', '周六', '周日'][i]),
                      );
                    }),
                    onChanged: (v) { if (v != null) setModalState(() => selectedWeekday = v); },
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
                              context: ctx, initialTime: repeatStart ?? const TimeOfDay(hour: 8, minute: 0),
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
                              context: ctx, initialTime: repeatEnd ?? const TimeOfDay(hour: 9, minute: 0),
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
                        context: ctx, initialTime: eventTimeOfDay ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (t != null) setModalState(() => eventTimeOfDay = t);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('开启提醒'),
                  subtitle: Text(
                    needReminder ? '提前 $reminderMinutes 分钟提醒' : '不提醒',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: needReminder,
                  onChanged: (v) => setModalState(() => needReminder = v),
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
                    onChanged: (v) { if (v != null) setModalState(() => reminderMinutes = v); },
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
                        if (isDateRange) {
                          await DatabaseService.addCalendarEvent(
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            eventType: 'date_range',
                            rangeStartDate: DateTime(rangeStart.year, rangeStart.month, rangeStart.day),
                            rangeEndDate: DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day),
                            repeatStartTime: repeatStart != null ? _formatTime(repeatStart!) : null,
                            repeatEndTime: repeatEnd != null ? _formatTime(repeatEnd!) : null,
                            needReminder: needReminder,
                            reminderMinutesBefore: reminderMinutes,
                          );
                        } else if (isLongTerm) {
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
                        if (isDateRange) {
                          await DatabaseService.updateCalendarEvent(
                            event.id,
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            rangeStartDate: DateTime(rangeStart.year, rangeStart.month, rangeStart.day),
                            rangeEndDate: DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day),
                            repeatStartTime: repeatStart != null ? _formatTime(repeatStart!) : null,
                            repeatEndTime: repeatEnd != null ? _formatTime(repeatEnd!) : null,
                            needReminder: needReminder,
                            reminderMinutesBefore: reminderMinutes,
                          );
                        } else if (isLongTerm) {
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
