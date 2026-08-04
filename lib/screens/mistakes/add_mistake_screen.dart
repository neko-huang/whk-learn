import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';
import '../../services/image_service.dart';
import '../../services/notification_service.dart';
import '../../utils/spaced_repetition.dart';

/// 添加/编辑易错点页面
class AddMistakeScreen extends ConsumerStatefulWidget {
  final int? initialSubjectId;
  final int? editId;

  const AddMistakeScreen({super.key, this.initialSubjectId, this.editId});

  @override
  ConsumerState<AddMistakeScreen> createState() => _AddMistakeScreenState();
}

class _AddMistakeScreenState extends ConsumerState<AddMistakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _chapterController = TextEditingController();
  final _tagsController = TextEditingController();

  int? _selectedSubjectId;
  int _difficultyLevel = 3; // 默认中等难度
  List<String> _imagePaths = [];
  List<int> _existingImageIds = [];
  bool _isSaving = false;
  bool _enableReview = true; // 是否启用艾宾浩斯提醒
  bool _isLoading = false;

  List<Subject> _subjects = [];

  bool get _isEditing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId;
    _loadSubjects();
    if (_isEditing) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseService.getMistakeById(widget.editId!);
      if (data != null && mounted) {
        _titleController.text = data.mistake.title;
        _descriptionController.text = data.mistake.description;
        _chapterController.text = data.mistake.chapter;
        _tagsController.text = data.tagList.join(',');
        _selectedSubjectId = data.mistake.subjectId;
        _difficultyLevel = data.mistake.difficultyLevel;
        _imagePaths = data.images.map((img) => img.imagePath).toList();
        _existingImageIds = data.images.map((img) => img.id).toList();
        _enableReview = data.mistake.nextReviewDate != null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载数据失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubjects() async {
    final stage = ref.read(stageProvider);
    final subjects = await DatabaseService.getVisibleSubjects(stage: stage);
    setState(() {
      _subjects = subjects;
      _selectedSubjectId ??= subjects.isNotEmpty ? subjects.first.id : null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _chapterController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑易错点' : '添加易错点'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 科目选择
            _buildSectionTitle('科目 *'),
            const SizedBox(height: 8),
            _buildSubjectSelector(),
            const SizedBox(height: 24),

            // 章节
            _buildSectionTitle('章节'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _chapterController,
              decoration: const InputDecoration(
                hintText: '如：函数与导数、力学分析...',
              ),
            ),
            const SizedBox(height: 24),

            // 标题
            _buildSectionTitle('标题 *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '简要描述这个易错点',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入标题';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // 详细描述
            _buildSectionTitle('详细描述'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: '详细说明错误原因、正确解法...',
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 24),

            // 标签
            _buildSectionTitle('标签'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                hintText: '用逗号分隔，如：粗心,概念不清,计算错误',
              ),
            ),
            const SizedBox(height: 24),

            // 难度等级
            _buildSectionTitle('难度等级'),
            const SizedBox(height: 8),
            _buildDifficultySelector(),
            const SizedBox(height: 24),

            // 图片
            _buildSectionTitle('图片'),
            const SizedBox(height: 8),
            _buildImageSection(),
            const SizedBox(height: 24),

            // 复习提醒
            _buildSectionTitle('复习提醒'),
            const SizedBox(height: 8),
            _buildReviewSetting(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildSubjectSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _subjects.map((subject) {
        final isSelected = _selectedSubjectId == subject.id;
        return InkWell(
          onTap: () => setState(() => _selectedSubjectId = subject.id),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? subject.displayColor : subject.displayColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: subject.displayColor,
                width: isSelected ? 0 : 1,
              ),
            ),
            child: Text(
              subject.name,
              style: TextStyle(
                color: isSelected ? Colors.white : subject.displayColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDifficultySelector() {
    return Row(
      children: List.generate(5, (index) {
        final level = index + 1;
        final isSelected = _difficultyLevel == level;
        final colors = [Colors.green, Colors.lightGreen, Colors.orange, Colors.deepOrange, Colors.red];
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _difficultyLevel = level),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? colors[index] : colors[index].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      level == 1 ? '简单' : level == 2 ? '较易' : level == 3 ? '中等' : level == 4 ? '较难' : '困难',
                      style: TextStyle(
                        color: isSelected ? Colors.white : colors[index],
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        // 已添加的图片
        if (_imagePaths.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imagePaths.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePaths[index]),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: InkWell(
                        onTap: () {
                          setState(() => _imagePaths.removeAt(index));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        const SizedBox(height: 12),

        // 添加图片按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('拍照'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('相册'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewSetting() {
    return SwitchListTile(
      title: const Text('启用艾宾浩斯复习提醒'),
      subtitle: Text(
        _enableReview ? '系统将按遗忘曲线提醒复习' : '关闭后不会收到复习提醒',
        style: const TextStyle(fontSize: 12),
      ),
      value: _enableReview,
      onChanged: (value) => setState(() => _enableReview = value),
    );
  }

  Future<void> _takePhoto() async {
    final path = await ImageService.takePhoto();
    if (path != null) {
      setState(() => _imagePaths.add(path));
    }
  }

  Future<void> _pickFromGallery() async {
    final path = await ImageService.pickFromGallery();
    if (path != null) {
      setState(() => _imagePaths.add(path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择科目')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 构建标签 JSON（使用 jsonEncode 避免特殊字符问题）
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final tagsJson = tags.isNotEmpty ? jsonEncode(tags) : '';

      if (_isEditing) {
        // 编辑模式：更新已有易错点
        await DatabaseService.updateMistake(
          widget.editId!,
          title: _titleController.text,
          description: _descriptionController.text,
          subjectId: _selectedSubjectId!,
          chapter: _chapterController.text,
          tags: tagsJson,
          difficultyLevel: _difficultyLevel,
        );

        // 删除旧图片，重新添加
        for (final imgId in _existingImageIds) {
          await DatabaseService.deleteMistakeImage(imgId);
        }
        for (int i = 0; i < _imagePaths.length; i++) {
          await DatabaseService.addMistakeImage(widget.editId!, _imagePaths[i], i);
        }

        // 更新复习提醒
        if (_enableReview) {
          final nextReviewDate = SpacedRepetition.getNextReviewDate(
            lastReviewDate: DateTime.now(),
            reviewCount: 0,
            difficultyLevel: _difficultyLevel,
          );
          await DatabaseService.updateMistake(
            widget.editId!,
            nextReviewDate: nextReviewDate,
          );
          final subject = _subjects.firstWhere((s) => s.id == _selectedSubjectId);
          await NotificationService.scheduleReviewNotification(
            mistakeId: widget.editId!,
            title: _titleController.text,
            subjectName: subject.name,
            scheduledDate: nextReviewDate,
          );
        } else {
          await DatabaseService.updateMistake(widget.editId!, nextReviewDate: null);
          await NotificationService.cancelNotification(widget.editId!);
        }
      } else {
        // 新建模式
        final mistakeId = await DatabaseService.addMistake(
          title: _titleController.text,
          description: _descriptionController.text,
          subjectId: _selectedSubjectId!,
          chapter: _chapterController.text,
          tags: tagsJson,
          difficultyLevel: _difficultyLevel,
        );

        // 保存图片
        for (int i = 0; i < _imagePaths.length; i++) {
          await DatabaseService.addMistakeImage(mistakeId, _imagePaths[i], i);
        }

        // 设置复习提醒
        if (_enableReview) {
          final nextReviewDate = SpacedRepetition.getNextReviewDate(
            lastReviewDate: DateTime.now(),
            reviewCount: 0,
            difficultyLevel: _difficultyLevel,
          );
          await DatabaseService.updateMistake(
            mistakeId,
            nextReviewDate: nextReviewDate,
          );
          final subject = _subjects.firstWhere((s) => s.id == _selectedSubjectId);
          await NotificationService.scheduleReviewNotification(
            mistakeId: mistakeId,
            title: _titleController.text,
            subjectName: subject.name,
            scheduledDate: nextReviewDate,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功！')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
