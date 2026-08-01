import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/database_service.dart';

/// 专注预设时长选项（分钟）
const List<int> _focusDurations = [15, 30, 45, 60, 90, 120];

/// 鼓励语列表
const List<String> _encouragements = [
  '放下手机，专注当下 💪',
  '你的努力终将有所回报 🌟',
  '每一分钟都值得被珍惜 ⏰',
  '坚持下去，你比想象中更强大 ✨',
  '专注是最好的投资 📚',
  '远离干扰，拥抱效率 🎯',
  '此刻的自律，明日的自由 🌈',
  '深呼吸，投入学习 🧘',
];

/// 确认退出文字
const String _confirmExitText = '我确定要放弃';

/// 专注模式入口页面（时长选择）
class FocusModeEntryScreen extends ConsumerWidget {
  const FocusModeEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('离开手机'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部介绍
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.phone_android,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '专注模式',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '选择专注时长，放下手机，专注于学习。\n退出需要完成三步验证，帮助你坚持到底。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '选择专注时长',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // 时长选择网格
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _focusDurations.length,
                itemBuilder: (context, index) {
                  final minutes = _focusDurations[index];
                  return _buildDurationCard(context, minutes);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard(BuildContext context, int minutes) {
    String label;
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      label = m > 0 ? '$h小时$m分钟' : '$h小时';
    } else {
      label = '$minutes 分钟';
    }

    final icons = [
      Icons.flash_on,
      Icons.timer,
      Icons.hourglass_bottom,
      Icons.schedule,
      Icons.access_time_filled,
      Icons.alarm,
    ];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FocusModeScreen(durationMinutes: minutes),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icons[_focusDurations.indexOf(minutes) % icons.length],
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// 专注模式主页面（倒计时 + 退出验证）
class FocusModeScreen extends ConsumerStatefulWidget {
  final int durationMinutes;

  const FocusModeScreen({super.key, required this.durationMinutes});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen> {
  late int _totalSeconds;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isCompleted = false;
  // ignore: unused_field
  bool _isRunning = false;
  late String _encouragement;
  DateTime? _startTime;

  // 退出验证状态
  int _exitStep = 0; // 0=未触发, 1=长按, 2=数学题, 3=输入文字
  bool _longPressSatisfied = false;

  // 数学题
  late int _mathA;
  late int _mathB;
  late String _mathOp;
  late int _mathAnswer;
  final _mathController = TextEditingController();

  // 确认文字
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.durationMinutes * 60;
    _remainingSeconds = _totalSeconds;
    _encouragement = _encouragements[Random().nextInt(_encouragements.length)];
    _generateMathQuestion();
    // 自动开始
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mathController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _generateMathQuestion() {
    final random = Random();
    _mathA = random.nextInt(80) + 10; // 10-89
    _mathB = random.nextInt(80) + 10; // 10-89
    _mathOp = random.nextBool() ? '+' : '-';
    // 确保减法不为负
    if (_mathOp == '-' && _mathA < _mathB) {
      final temp = _mathA;
      _mathA = _mathB;
      _mathB = temp;
    }
    _mathAnswer = _mathOp == '+' ? _mathA + _mathB : _mathA - _mathB;
  }

  void _startTimer() {
    _startTime = DateTime.now();
    setState(() => _isRunning = true);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _completeFocus();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _completeFocus() {
    _timer?.cancel();
    setState(() {
      _isCompleted = true;
      _isRunning = false;
      _remainingSeconds = 0;
    });
    _saveRecord();
  }

  Future<void> _saveRecord() async {
    final now = DateTime.now();
    final start = _startTime ?? now.subtract(Duration(seconds: _totalSeconds));
    await DatabaseService.addPomodoroRecord(
      startTime: start,
      endTime: now,
      duration: widget.durationMinutes,
      type: 'focus_mode',
      completed: _isCompleted,
    );
  }

  void _attemptExit() {
    _generateMathQuestion();
    setState(() {
      _exitStep = 1;
      _longPressSatisfied = false;
    });
    _mathController.clear();
    _confirmController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCompleted) {
      return _buildCompletionScreen();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: _exitStep > 0 ? _buildExitVerification() : _buildFocusContent(),
        ),
      ),
    );
  }

  Widget _buildFocusContent() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final progress = 1.0 - (_remainingSeconds / _totalSeconds);
    final theme = Theme.of(context);

    return Column(
      children: [
        const Spacer(),
        // 鼓励语
        Text(
          _encouragement,
          style: TextStyle(
            fontSize: 20,
            color: theme.colorScheme.primary.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        // 大字体倒计时
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 280,
              height: 280,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                color: theme.colorScheme.primary,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '剩余 ${widget.durationMinutes} 分钟',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        const Spacer(),
        // 提前结束按钮（故意不显眼）
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: GestureDetector(
            onLongPressStart: (_) {
              // 长按3秒后触发
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted && _exitStep == 0) {
                  // 已自动进入验证
                }
              });
            },
            child: TextButton(
              onPressed: null, // 禁用普通点击
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                '想要提前结束？长按此处',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        // 隐藏的长按退出区域
        GestureDetector(
          onLongPressStart: (_) {
            _startLongPressTimer();
          },
          onLongPressEnd: (_) {
            _cancelLongPressTimer();
          },
          child: Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _longPressSatisfied
                  ? Colors.red.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.power_settings_new,
                size: 20,
                color: _longPressSatisfied ? Colors.red : Colors.grey.shade400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Timer? _longPressTimer;

  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _longPressSatisfied = true);
        _attemptExit();
      }
    });
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  Widget _buildExitVerification() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // 步骤指示
          _buildStepIndicator(),
          const SizedBox(height: 32),
          // 步骤内容
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStepContent(),
            ),
          ),
          // 取消按钮
          TextButton(
            onPressed: () {
              setState(() {
                _exitStep = 0;
                _longPressSatisfied = false;
              });
            },
            child: const Text('返回专注'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final stepNum = index + 1;
        final isActive = _exitStep >= stepNum;
        final isCurrent = _exitStep == stepNum;

        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Colors.green
                    : Colors.grey.shade300,
              ),
              child: Center(
                child: isActive && !isCurrent
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text(
                        '$stepNum',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (index < 2)
              Container(
                width: 40,
                height: 2,
                color: _exitStep > stepNum ? Colors.green : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_exitStep) {
      case 1:
        return _buildStep1Content();
      case 2:
        return _buildStep2Content();
      case 3:
        return _buildStep3Content();
      default:
        return const SizedBox();
    }
  }

  /// 第一步：长按退出按钮 3 秒
  Widget _buildStep1Content() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.touch_app, size: 64, color: Colors.orange),
        const SizedBox(height: 24),
        const Text(
          '第一步',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text(
          '长按下方按钮 3 秒',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onLongPressStart: (_) => _startExitLongPress(),
          onLongPressEnd: (_) => _cancelExitLongPress(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _exitStep1Progress > 0
                  ? Colors.red.withOpacity(0.2 + _exitStep1Progress * 0.6)
                  : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red,
                width: 3,
              ),
            ),
            child: Center(
              child: _exitStep1Progress >= 1.0
                  ? const Icon(Icons.check, size: 40, color: Colors.white)
                  : Text(
                      '${(3 - _exitStep1Progress * 3).toInt() + 1}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _exitStep1Progress > 0 ? '继续保持...' : '按住！',
          style: TextStyle(
            color: _exitStep1Progress > 0 ? Colors.green : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  double _exitStep1Progress = 0;
  Timer? _exitLongPressTimer;

  void _startExitLongPress() {
    _exitStep1Progress = 0;
    _exitLongPressTimer?.cancel();
    _exitLongPressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_exitStep1Progress >= 1.0) {
        _exitLongPressTimer?.cancel();
        // 第一步完成，进入第二步
        setState(() {
          _exitStep = 2;
          _exitStep1Progress = 1.0;
        });
        return;
      }
      setState(() {
        _exitStep1Progress += 0.05 / 3.0; // 3 seconds to fill
        if (_exitStep1Progress > 1.0) _exitStep1Progress = 1.0;
      });
    });
  }

  void _cancelExitLongPress() {
    _exitLongPressTimer?.cancel();
    setState(() => _exitStep1Progress = 0);
  }

  /// 第二步：解数学题
  Widget _buildStep2Content() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calculate, size: 64, color: Colors.blue),
        const SizedBox(height: 24),
        const Text(
          '第二步',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text(
          '解出这道数学题',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$_mathA $_mathOp $_mathB = ?',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          child: TextField(
            controller: _mathController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '答案',
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            onSubmitted: (_) => _checkMathAnswer(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _checkMathAnswer,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
          ),
          child: const Text('提交答案'),
        ),
      ],
    );
  }

  void _checkMathAnswer() {
    final answer = int.tryParse(_mathController.text.trim());
    if (answer == _mathAnswer) {
      setState(() => _exitStep = 3);
    } else {
      // 答错了，重新生成题目
      _generateMathQuestion();
      _mathController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('答案不对，换一道题试试'),
          duration: Duration(seconds: 1),
        ),
      );
      setState(() {});
    }
  }

  /// 第三步：输入确认文字
  Widget _buildStep3Content() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.red),
        const SizedBox(height: 24),
        const Text(
          '最后一步',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        const Text(
          '输入以下文字确认退出',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Text(
            _confirmExitText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 280,
          child: TextField(
            controller: _confirmController,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '请输入上方文字',
            ),
            onSubmitted: (_) => _checkConfirmText(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _checkConfirmText,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('确认放弃专注'),
        ),
      ],
    );
  }

  void _checkConfirmText() {
    if (_confirmController.text.trim() == _confirmExitText) {
      // 全部通过，退出专注
      _timer?.cancel();
      _saveRecordAsAbandoned();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('输入不正确，请仔细复制上方文字'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveRecordAsAbandoned() async {
    final now = DateTime.now();
    final start = _startTime ?? now;
    final elapsedMinutes = now.difference(start).inMinutes.clamp(1, widget.durationMinutes);
    await DatabaseService.addPomodoroRecord(
      startTime: start,
      endTime: now,
      duration: elapsedMinutes,
      type: 'focus_mode',
      completed: false,
    );
  }

  /// 完成页面
  Widget _buildCompletionScreen() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.celebration, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  '专注完成！',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  '你成功专注了 ${widget.durationMinutes} 分钟 🎉',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _encouragements[Random().nextInt(_encouragements.length)],
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('返回', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
