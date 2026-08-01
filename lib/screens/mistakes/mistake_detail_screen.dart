import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/image_service.dart';
import '../../utils/spaced_repetition.dart';

/// 易错点详情 Provider
class MistakeDetailProvider extends StateNotifier<AsyncValue<MistakeWithSubject?>> {
  final int mistakeId;

  MistakeDetailProvider(this.mistakeId) : super(const AsyncValue.loading()) {
    loadData();
  }

  Future<void> loadData() async {
    try {
      final data = await DatabaseService.getMistakeById(mistakeId);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// 易错点详情页面
class MistakeDetailScreen extends ConsumerStatefulWidget {
  final int mistakeId;

  const MistakeDetailScreen({super.key, required this.mistakeId});

  @override
  ConsumerState<MistakeDetailScreen> createState() => _MistakeDetailScreenState();
}

class _MistakeDetailScreenState extends ConsumerState<MistakeDetailScreen> {
  bool _isReviewing = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(MistakeDetailProvider(widget.mistakeId));

    return detail.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('加载失败: $e')),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('未找到该易错点')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(data.subject.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditDialog(context, data),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context, data),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Text(
                  data.mistake.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // 元信息
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: data.subject.displayColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        data.subject.name,
                        style: TextStyle(
                          color: data.subject.displayColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (data.mistake.chapter.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        data.mistake.chapter,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                    const Spacer(),
                    // 难度
                    Row(
                      children: List.generate(
                        data.mistake.difficultyLevel,
                        (i) => const Icon(Icons.star, size: 16, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 复习状态
                _buildReviewStatusCard(data),
                const SizedBox(height: 16),

                // 描述
                if (data.mistake.description.isNotEmpty) ...[
                  const Text(
                    '详细描述',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(data.mistake.description),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 标签
                if (data.tagList.isNotEmpty) ...[
                  const Text(
                    '标签',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.tagList.map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Colors.grey.shade200,
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // 图片
                if (data.images.isNotEmpty) ...[
                  const Text(
                    '题目图片',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...data.images.map((img) => _buildImageCard(img.imagePath)),
                  const SizedBox(height: 16),
                ],

                // 时间信息
                Card(
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('创建时间', _formatDateTime(data.mistake.createdAt)),
                        _buildInfoRow('更新时间', _formatDateTime(data.mistake.updatedAt)),
                        _buildInfoRow('复习次数', '${data.mistake.reviewCount} 次'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // 底部操作按钮
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _isReviewing ? null : () => _markAsReviewed(data),
                icon: _isReviewing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(data.mistake.needsReview ? '完成复习' : '已掌握'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewStatusCard(MistakeWithSubject data) {
    final needsReview = data.needsReview;
    return Card(
      color: needsReview ? Colors.orange.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              needsReview ? Icons.warning_amber : Icons.check_circle,
              color: needsReview ? Colors.orange : Colors.green,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    needsReview ? '需要复习' : '已掌握',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: needsReview ? Colors.orange.shade800 : Colors.green.shade800,
                    ),
                  ),
                  Text(
                    SpacedRepetition.getReviewStatusDescription(data.mistake.nextReviewDate),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(String imagePath) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showFullImage(imagePath),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(imagePath),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 100,
                color: Colors.grey.shade200,
                child: const Center(child: Text('图片加载失败')),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showFullImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }

  Future<void> _markAsReviewed(MistakeWithSubject data) async {
    setState(() => _isReviewing = true);

    try {
      final newReviewCount = data.mistake.reviewCount + 1;
      final nextReviewDate = SpacedRepetition.getNextReviewDate(
        lastReviewDate: DateTime.now(),
        reviewCount: newReviewCount,
        difficultyLevel: data.mistake.difficultyLevel,
      );

      await DatabaseService.updateMistake(
        data.mistake.id,
        reviewCount: newReviewCount,
        nextReviewDate: nextReviewDate,
      );

      // 更新提醒
      await NotificationService.scheduleReviewNotification(
        mistakeId: data.mistake.id,
        title: data.mistake.title,
        subjectName: data.subject.name,
        scheduledDate: nextReviewDate,
      );

      // 刷新数据
      ref.invalidate(MistakeDetailProvider(widget.mistakeId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下次复习: ${_formatDate(nextReviewDate)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReviewing = false);
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}月${dt.day}日';
  }

  void _showEditDialog(BuildContext context, MistakeWithSubject data) {
    // 简化：跳转到编辑页面（可以复用添加页面）
    context.push('/mistakes/add?editId=${data.mistake.id}');
  }

  Future<void> _confirmDelete(BuildContext context, MistakeWithSubject data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${data.mistake.title}」吗？'),
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
      // 删除通知
      await NotificationService.cancelNotification(data.mistake.id);
      
      // 删除图片
      for (final img in data.images) {
        await ImageService.deleteImage(img.imagePath);
      }
      
      // 删除记录
      await DatabaseService.deleteMistake(data.mistake.id);

      if (mounted) {
        context.pop();
      }
    }
  }
}
