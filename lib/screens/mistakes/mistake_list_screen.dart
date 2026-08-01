import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/database.dart';
import '../../models/mistake.dart';
import '../../services/database_service.dart';

/// 所有科目 Provider
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  return await DatabaseService.getVisibleSubjects();
});

/// 易错点列表 Provider
class MistakeListNotifier extends StateNotifier<AsyncValue<List<MistakeWithSubject>>> {
  int? _subjectId;
  String _searchKeyword = '';

  MistakeListNotifier() : super(const AsyncValue.loading()) {
    loadData();
  }

  Future<void> loadData() async {
    state = const AsyncValue.loading();
    try {
      final data = await DatabaseService.getMistakes(
        subjectId: _subjectId,
        searchKeyword: _searchKeyword.isNotEmpty ? _searchKeyword : null,
      );
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void filterBySubject(int? subjectId) {
    _subjectId = subjectId;
    loadData();
  }

  void search(String keyword) {
    _searchKeyword = keyword;
    loadData();
  }
}

final mistakeListProvider =
    StateNotifierProvider<MistakeListNotifier, AsyncValue<List<MistakeWithSubject>>>(
  MistakeListNotifier.new,
);

/// 易错点列表页面
class MistakeListScreen extends ConsumerStatefulWidget {
  const MistakeListScreen({super.key});

  @override
  ConsumerState<MistakeListScreen> createState() => _MistakeListScreenState();
}

class _MistakeListScreenState extends ConsumerState<MistakeListScreen> {
  final _searchController = TextEditingController();
  int? _selectedSubjectId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mistakes = ref.watch(mistakeListProvider);
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('易错点'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(subjects),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索标题、描述、标签...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(mistakeListProvider.notifier).search('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(mistakeListProvider.notifier).search(value);
              },
            ),
          ),

          // 科目筛选标签
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildSubjectChip(null, '全部'),
                ...subjects.whenOrNull(
                      data: (data) => data.map((s) => _buildSubjectChip(s.id, s.name, s.displayColor)).toList(),
                    ) ??
                    [],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mistakeListProvider);
              },
              child: mistakes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
                data: (data) {
                  if (data.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty ? '没有找到匹配的内容' : '还没有记录易错点',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: data.length,
                    itemBuilder: (context, index) => _buildMistakeCard(data[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/mistakes/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSubjectChip(int? id, String label, [Color? color]) {
    final isSelected = _selectedSubjectId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: (color ?? Colors.blue).withOpacity(0.2),
        onSelected: (selected) {
          setState(() {
            _selectedSubjectId = selected ? id : null;
          });
          ref.read(mistakeListProvider.notifier).filterBySubject(selected ? id : null);
        },
      ),
    );
  }

  Widget _buildMistakeCard(MistakeWithSubject item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/mistakes/${item.mistake.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.subject.displayColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.subject.name,
                      style: TextStyle(
                        color: item.subject.displayColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (item.mistake.images.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${item.mistake.images.length}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 标题
              Text(
                item.mistake.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),

              // 描述（如果有）
              if (item.mistake.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.mistake.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],

              // 标签和章节
              if (item.mistake.chapter.isNotEmpty || item.tagList.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (item.mistake.chapter.isNotEmpty)
                      Chip(
                        label: Text(item.mistake.chapter, style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ...item.tagList.take(3).map((tag) => Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 11)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )),
                  ],
                ),
              ],

              // 复习状态
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    item.needsReview ? Icons.warning_amber : Icons.check_circle,
                    size: 16,
                    color: item.needsReview ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.needsReview ? '待复习' : '已掌握',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.needsReview ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(AsyncValue<List<Subject>> subjects) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选科目'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: subjects.whenOrNull(
                  data: (data) => [
                    ListTile(
                      title: const Text('全部科目'),
                      selected: _selectedSubjectId == null,
                      onTap: () {
                        setState(() => _selectedSubjectId = null);
                        ref.read(mistakeListProvider.notifier).filterBySubject(null);
                        Navigator.pop(context);
                      },
                    ),
                    ...data.map((s) => ListTile(
                          title: Text(s.name),
                          leading: CircleAvatar(backgroundColor: s.displayColor, radius: 10),
                          selected: _selectedSubjectId == s.id,
                          onTap: () {
                            setState(() => _selectedSubjectId = s.id);
                            ref.read(mistakeListProvider.notifier).filterBySubject(s.id);
                            Navigator.pop(context);
                          },
                        )),
                  ],
                ) ??
                [],
          ),
        ),
      ),
    );
  }
}
