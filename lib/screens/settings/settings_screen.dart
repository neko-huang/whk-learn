import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../app.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';

/// 设置页面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<Subject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final subjects = await DatabaseService.getAllSubjects();
    setState(() {
      _subjects = subjects;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final stage = ref.watch(stageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 外观设置
                _buildSectionHeader('外观'),
                SwitchListTile(
                  title: const Text('深色模式'),
                  subtitle: const Text('减少屏幕亮度，保护眼睛'),
                  value: isDarkMode,
                  onChanged: (value) async {
                    ref.read(isDarkModeProvider.notifier).state = value;
                    await SettingsService.saveDarkMode(value);
                  },
                ),
                const Divider(),

                // 学段选择
                _buildSectionHeader('学段'),
                ListTile(
                  title: const Text('当前学段'),
                  subtitle: Text(_getStageName(stage)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showStageDialog(stage),
                ),
                const Divider(),

                // 科目管理
                _buildSectionHeader('科目管理'),
                ..._subjects.map((subject) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: subject.displayColor,
                    radius: 16,
                    child: Text(
                      subject.name.substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(subject.name),
                  trailing: subject.id <= 9
                      ? null // 默认科目不可删除
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteSubject(subject),
                        ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                  title: const Text('添加自定义科目'),
                  onTap: () => _showAddSubjectDialog(),
                ),
                const Divider(),

                // 通知设置
                _buildSectionHeader('提醒'),
                SwitchListTile(
                  title: const Text('复习提醒'),
                  subtitle: const Text('基于艾宾浩斯遗忘曲线推送通知'),
                  value: true,
                  onChanged: (value) async {
                    if (value) {
                      await NotificationService.requestPermission();
                    }
                  },
                ),
                const Divider(),

                // 数据管理
                _buildSectionHeader('数据'),
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('导出数据'),
                  subtitle: const Text('导出所有易错点为文件'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('功能开发中...')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('导入数据'),
                  subtitle: const Text('从文件恢复数据'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('功能开发中...')),
                    );
                  },
                ),
                const Divider(),

                // 关于
                _buildSectionHeader('关于'),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('学助'),
                  subtitle: Text('版本 1.0.0'),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _getStageName(String stage) {
    switch (stage) {
      case 'junior':
        return '初中';
      case 'high_school':
        return '高中';
      case 'college':
        return '大学/考研';
      default:
        return '高中';
    }
  }

  void _showStageDialog(String currentStage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择学段'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStageOption('junior', '初中', currentStage == 'junior'),
            _buildStageOption('high_school', '高中', currentStage == 'high_school'),
            _buildStageOption('college', '大学/考研', currentStage == 'college'),
          ],
        ),
      ),
    );
  }

  Widget _buildStageOption(String value, String label, bool isSelected) {
    return ListTile(
      title: Text(label),
      selected: isSelected,
      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        ref.read(stageProvider.notifier).state = value;
        await SettingsService.saveStage(value);
        Navigator.pop(context);
      },
    );
  }

  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    String selectedColor = '#2196F3';
    
    final colors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFC107', '#FF9800', '#FF5722', '#795548',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加科目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '科目名称',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final isSelected = selectedColor == color;
                  return InkWell(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await DatabaseService.addSubject(controller.text, selectedColor);
                  await _loadData();
                  Navigator.pop(context);
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSubject(Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除科目「${subject.name}」吗？该科目下的易错点不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await DatabaseService.database;
      await (db.update(db.subjects)..where((t) => t.id.equals(subject.id))).write(
        SubjectsCompanion(isVisible: const Value(false)),
      );
      await _loadData();
    }
  }
}
