import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';

/// 番茄钟类型
enum PomodoroType {
  focus('专注', 25),
  shortBreak('短休息', 5),
  longBreak('长休息', 15);

  final String label;
  final int defaultMinutes;
  const PomodoroType(this.label, this.defaultMinutes);
}

/// 番茄钟状态
enum TimerState {
  idle,
  running,
  paused,
  completed,
}

/// 今日番茄钟数量 Provider
final todayPomodoroCountProvider = FutureProvider<int>((ref) async {
  return await DatabaseService.getTodayPomodoroCount();
});

/// 今日学习时长 Provider（分钟）
final todayStudyMinutesProvider = FutureProvider<int>((ref) async {
  return await DatabaseService.getTodayStudyMinutes();
});

/// 番茄钟页面
class PomodoroScreen extends ConsumerStatefulWidget {
  final int? initialSubjectId;
  final int? initialPlanId;

  const PomodoroScreen({
    super.key,
    this.initialSubjectId,
    this.initialPlanId,
  });

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  PomodoroType _currentType = PomodoroType.focus;
  TimerState _timerState = TimerState.idle;

  int _totalSeconds = PomodoroType.focus.defaultMinutes * 60;
  int _remainingSeconds = PomodoroType.focus.defaultMinutes * 60;
  Timer? _timer;

  // 使用 DateTime 记录开始/暂停时间，支持后台计时
  DateTime? _sessionStart;
  int _elapsedBeforePause = 0;

  int? _selectedSubjectId;
  int? _selectedPlanId;
  List<Subject> _subjects = [];
  List<StudyPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
    _selectedPlanId = widget.initialPlanId;
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final subjects = await DatabaseService.getVisibleSubjects();
    final plans = await DatabaseService.getAllStudyPlans();
    if (mounted) {
      setState(() {
        _subjects = subjects;
        _plans = plans.where((p) => p.status == 'in_progress' || p.status == 'pending').toList();
      });
    }
  }

  void _startTimer() {
    if (_timerState == TimerState.idle || _timerState == TimerState.completed) {
      // 全新开始
      _elapsedBeforePause = 0;
      _sessionStart = DateTime.now();
    } else if (_timerState == TimerState.paused) {
      // 从暂停恢复
      _sessionStart = DateTime.now();
    }

    setState(() => _timerState = TimerState.running);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (_sessionStart == null) return;

    final elapsed = _elapsedBeforePause + DateTime.now().difference(_sessionStart!).inSeconds;
    final remaining = _totalSeconds - elapsed;

    if (remaining <= 0) {
      _completeSession();
    } else {
      setState(() => _remainingSeconds = remaining);
    }
  }

  void _pauseTimer() {
    if (_timerState != TimerState.running) return;

    _timer?.cancel();
    if (_sessionStart != null) {
      _elapsedBeforePause += DateTime.now().difference(_sessionStart!).inSeconds;
    }
    setState(() => _timerState = TimerState.paused);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerState = TimerState.idle;
      _totalSeconds = _currentType.defaultMinutes * 60;
      _remainingSeconds = _totalSeconds;
      _elapsedBeforePause = 0;
      _sessionStart = null;
    });
  }

  void _completeSession() {
    _timer?.cancel();
    setState(() {
      _timerState = TimerState.completed;
      _remainingSeconds = 0;
    });

    // 保存到数据库
    _saveRecord();

    // 刷新 Provider
    ref.invalidate(todayPomodoroCountProvider);
    ref.invalidate(todayStudyMinutesProvider);

    // 显示完成对话框
    _showCompletionDialog();
  }

  Future<void> _saveRecord() async {
    final now = DateTime.now();
    final startTime = now.subtract(Duration(seconds: _totalSeconds));

    await DatabaseService.addPomodoroRecord(
      subjectId: _currentType == PomodoroType.focus ? _selectedSubjectId : null,
      planId: _currentType == PomodoroType.focus ? _selectedPlanId : null,
      startTime: startTime,
      endTime: now,
      duration: _totalSeconds ~/ 60, // 分钟
      type: _currentType == PomodoroType.focus
          ? 'focus'
          : _currentType == PomodoroType.shortBreak
              ? 'short_break'
              : 'long_break',
      completed: true,
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _currentType == PomodoroType.focus ? Icons.celebration : Icons.coffee,
              color: _currentType == PomodoroType.focus ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 8),
            const Text('完成！'),
          ],
        ),
        content: Text(
          _currentType == PomodoroType.focus
              ? '太棒了！你完成了一个 ${_totalSeconds ~/ 60} 分钟的专注时段 🎉'
              : '休息结束，准备好开始下一段学习了吗？',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetTimer();
            },
            child: const Text('好的'),
          ),
          if (_currentType == PomodoroType.focus)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // 自动切换到休息
                setState(() {
                  _currentType = PomodoroType.shortBreak;
                  _totalSeconds = _currentType.defaultMinutes * 60;
                  _remainingSeconds = _totalSeconds;
                });
                _startTimer();
              },
              child: const Text('开始休息'),
            ),
        ],
      ),
    );
  }

  void _switchType(PomodoroType type) {
    if (_timerState == TimerState.running) return; // 运行中不能切换
    setState(() {
      _currentType = type;
      _totalSeconds = type.defaultMinutes * 60;
      _remainingSeconds = _totalSeconds;
      _timerState = TimerState.idle;
      _elapsedBeforePause = 0;
      _sessionStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final todayCount = ref.watch(todayPomodoroCountProvider);
    final todayMinutes = ref.watch(todayStudyMinutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄钟'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 今日统计
            _buildTodayStats(todayCount, todayMinutes),
            const SizedBox(height: 32),

            // 类型选择
            _buildTypeSelector(),
            const SizedBox(height: 40),

            // 计时器
            _buildTimerDisplay(),
            const SizedBox(height: 40),

            // 控制按钮
            _buildControlButtons(),
            const SizedBox(height: 32),

            // 科目和计划选择（仅专注模式）
            if (_currentType == PomodoroType.focus) ...[
              _buildSubjectSelector(),
              const SizedBox(height: 16),
              _buildPlanSelector(),
            ],
          ],
        ),
      ),
    );
  }

  /// 今日统计
  Widget _buildTodayStats(AsyncValue<int> count, AsyncValue<int> minutes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                const SizedBox(height: 4),
                count.when(
                  loading: () => const Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  error: (_, __) => const Text('0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  data: (c) => Text('$c', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const Text('今日番茄', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            Column(
              children: [
                const Icon(Icons.timer, color: Colors.blue, size: 28),
                const SizedBox(height: 4),
                minutes.when(
                  loading: () => const Text('--', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  error: (_, __) => const Text('0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  data: (m) => Text(_formatMinutes(m), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const Text('学习时长', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            Column(
              children: [
                Icon(_currentType == PomodoroType.focus ? Icons.timer : Icons.coffee, color: Colors.green, size: 28),
                const SizedBox(height: 4),
                Text(
                  '${_totalSeconds ~/ 60}m',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('当前设定', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 类型选择器
  Widget _buildTypeSelector() {
    return Row(
      children: PomodoroType.values.map((type) {
        final isSelected = type == _currentType;
        final isEnabled = _timerState != TimerState.running;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: isEnabled ? () => _switchType(type) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getTypeColor(type).withOpacity(0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _getTypeColor(type) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      type == PomodoroType.focus
                          ? Icons.timer
                          : type == PomodoroType.shortBreak
                              ? Icons.coffee
                              : Icons.weekend,
                      color: isSelected ? _getTypeColor(type) : Colors.grey,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? _getTypeColor(type) : Colors.grey,
                      ),
                    ),
                    Text(
                      '${type.defaultMinutes}分钟',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 计时器显示
  Widget _buildTimerDisplay() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = 1.0 - (_remainingSeconds / _totalSeconds);
    final typeColor = _getTypeColor(_currentType);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 圆形进度
        SizedBox(
          width: 260,
          height: 260,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            backgroundColor: Colors.grey.shade200,
            color: typeColor,
          ),
        ),
        // 时间文字
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: typeColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentType.label,
              style: TextStyle(fontSize: 16, color: typeColor.withOpacity(0.7)),
            ),
            if (_timerState == TimerState.paused)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '已暂停',
                  style: TextStyle(fontSize: 14, color: Colors.orange),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 控制按钮
  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 重置按钮
        if (_timerState != TimerState.idle)
          IconButton(
            onPressed: _resetTimer,
            icon: const Icon(Icons.refresh),
            iconSize: 32,
            color: Colors.grey,
          ),
        const SizedBox(width: 24),
        // 开始/暂停按钮
        ElevatedButton(
          onPressed: () {
            switch (_timerState) {
              case TimerState.idle:
              case TimerState.completed:
                _startTimer();
                break;
              case TimerState.running:
                _pauseTimer();
                break;
              case TimerState.paused:
                _startTimer();
                break;
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: Text(
            _timerState == TimerState.running ? '暂停' : '开始',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// 科目选择器
  Widget _buildSubjectSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择科目（可选）', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _subjects.map((s) {
                final isSelected = _selectedSubjectId == s.id;
                return ChoiceChip(
                  label: Text(s.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedSubjectId = selected ? s.id : null;
                    });
                  },
                  selectedColor: s.displayColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? s.displayColor : null,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 计划选择器
  Widget _buildPlanSelector() {
    if (_plans.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('关联学习计划（可选）', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plans.map((p) {
                final isSelected = _selectedPlanId == p.id;
                return ChoiceChip(
                  label: Text(p.title),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPlanId = selected ? p.id : null;
                    });
                  },
                  selectedColor: Colors.blue.withOpacity(0.2),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取类型颜色
  Color _getTypeColor(PomodoroType type) {
    switch (type) {
      case PomodoroType.focus:
        return Colors.red;
      case PomodoroType.shortBreak:
        return Colors.green;
      case PomodoroType.longBreak:
        return Colors.blue;
    }
  }

  /// 格式化分钟
  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h${m}m' : '${h}h';
    }
    return '${minutes}m';
  }
}
