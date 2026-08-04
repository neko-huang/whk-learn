import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/database_service.dart';

/// DeepSeek 聊天消息（内存模型）
class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime time;

  _ChatMessage({required this.role, required this.content, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// 分析专用系统提示词（仅在本周分析时使用，不影响普通聊天）
const _analysisPrompt = '''
你是一位专业的学习分析顾问。以下是用户本周的学习数据，请基于数据给出分析报告。

请按以下结构输出：

📊 **本周学习分析报告（第X周）**
━━━━━━━━━━━━━━━━━━━━━━

📅 **时间规划执行情况**
- 理想安排 vs 实际安排对比
- 完成率统计
- 每日执行情况概览

📊 **学习投入分析**
- 总学习时长
- 各科目学习时长排名
- 薄弱科目识别

🎯 **计划进度追踪**
- 各计划完成百分比
- 滞后/超前提醒

💡 **改进建议**
- 可操作的具体建议（2-3条）
- 针对薄弱科目的建议

📈 **本周亮点**
- 做得好的地方

注意：
1. 报告要简洁、直观、有数据支撑
2. 建议要具体可执行，不要泛泛而谈
3. 语气鼓励为主，适当指出问题
''';

/// DeepSeek 聊天页面
class DeepSeekScreen extends ConsumerStatefulWidget {
  const DeepSeekScreen({super.key});

  @override
  ConsumerState<DeepSeekScreen> createState() => _DeepSeekScreenState();
}

class _DeepSeekScreenState extends ConsumerState<DeepSeekScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];

  bool _loading = false;
  bool _loaded = false;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadChatHistory() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final records = await DatabaseService.getAllChatMessages();
      if (records.isNotEmpty && mounted) {
        setState(() {
          for (final r in records) {
            _messages.add(_ChatMessage(role: r.role, content: r.content, time: r.createdAt));
          }
        });
        _scrollToBottom();
        return;
      }
    } catch (_) {
      // 数据库还没准备好，用默认欢迎语
    }

    if (_messages.isEmpty && mounted) {
      setState(() {
        _messages.add(_ChatMessage(
          role: 'assistant',
          content: '你好！我是 DeepSeek AI 助手，有什么可以帮助你的吗？',
        ));
      });
    }
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('deepseek_api_key');
    if (mounted) {
      setState(() => _apiKey = key);
      _loadChatHistory();
      if (key == null || key.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showKeyDialog());
      }
    }
  }

  Future<void> _showKeyDialog() async {
    final ctrl = TextEditingController(text: _apiKey ?? '');
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('DeepSeek API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入你的 DeepSeek API Key，可在 platform.deepseek.com 获取。'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_api_key', result);
    if (mounted) setState(() => _apiKey = result);
  }

  // ───── 普通聊天 ─────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    if (_apiKey == null || _apiKey!.isEmpty) {
      _showKeyDialog();
      return;
    }

    // 保存用户消息
    await DatabaseService.addChatMessage(role: 'user', content: text);

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await _callDeepSeek(_buildContextMessages());
      if (mounted) {
        // 保存 AI 回复
        await DatabaseService.addChatMessage(role: 'assistant', content: reply);
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', content: reply));
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: '请求出错：$e\n\n请检查 API Key 或网络连接。',
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  /// 构建发送给 API 的上下文消息列表
  List<Map<String, dynamic>> _buildContextMessages() {
    return _messages.map((m) => m.toJson()).toList();
  }

  // ───── 本周分析 ─────

  Future<void> _startWeeklyAnalysis() async {
    if (_loading) return;
    if (_apiKey == null || _apiKey!.isEmpty) {
      _showKeyDialog();
      return;
    }

    setState(() => _loading = true);

    try {
      final data = await DatabaseService.getWeeklyAnalysisData();
      final dataJson = const JsonEncoder.withIndent('  ').convert(data);

      // 构造分析请求：系统提示 + 数据
      final analysisMessages = [
        {'role': 'system', 'content': _analysisPrompt},
        {'role': 'user', 'content': '这是我的本周学习数据，请分析：\n\n```json\n$dataJson\n```'},
      ];

      // 显示"分析中..."
      final loadingMsg = _ChatMessage(
        role: 'assistant',
        content: '📊 正在分析本周学习数据...',
      );
      setState(() {
        _messages.add(loadingMsg);
      });
      _scrollToBottom();

      final reply = await _callDeepSeek(analysisMessages);

      if (mounted) {
        // 移除"分析中..."，替换为实际结果
        setState(() {
          _messages.removeLast();
          _messages.add(_ChatMessage(role: 'assistant', content: reply));
          _loading = false;
        });
        // 存入数据库
        await DatabaseService.addChatMessage(role: 'assistant', content: reply);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.content.contains('正在分析')) {
            _messages.removeLast();
          }
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: '分析失败：$e\n\n请检查数据是否正常。',
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ───── API 调用 ─────

  Future<String> _callDeepSeek(List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final model = prefs.getString('deepseek_model') ?? 'deepseek-chat';
    final reasoningEffort = prefs.getString('deepseek_reasoning_effort') ?? 'off';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 60);

    try {
      // 截断上下文：保留第一条 + 最近 19 条
      if (messages.length > 20) {
        messages = [messages.first, ...messages.sublist(messages.length - 19)];
      }

      final body = <String, dynamic>{
        'model': model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 4096,
      };

      if (reasoningEffort != 'off') {
        body['reasoning_effort'] = reasoningEffort;
      }

      final req = await client.postUrl(Uri.parse('https://api.deepseek.com/v1/chat/completions'));
      req.headers.set('Content-Type', 'application/json; charset=utf-8');
      req.headers.set('Authorization', 'Bearer $_apiKey');
      // 用字节方式写入，避免中文等非ASCII字符被 HttpClient 视为非法字符
      req.add(utf8.encode(jsonEncode(body)));

      final res = await req.close();
      final responseBody = await res.transform(utf8.decoder).join();

      if (res.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return data['choices'][0]['message']['content'] as String;
      } else {
        final err = jsonDecode(responseBody);
        throw Exception('Error ${res.statusCode}: ${err['error']?['message'] ?? responseBody}');
      }
    } finally {
      client.close();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ───── UI ─────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DeepSeek'),
        actions: [
          // 本周分析按钮
          IconButton(
            icon: const Icon(Icons.analytics_outlined, size: 20),
            tooltip: '本周学习分析',
            onPressed: _startWeeklyAnalysis,
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            tooltip: '设置 API Key',
            onPressed: _showKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '清空对话',
            onPressed: () async {
              await DatabaseService.deleteAllChatMessages();
              if (mounted) {
                setState(() {
                  _messages.clear();
                  _messages.add(_ChatMessage(
                    role: 'assistant',
                    content: '对话已清空，有什么可以帮助你的吗？',
                  ));
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('开始对话吧！', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('思考中...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        );
                      }
                      return _buildBubble(_messages[i]);
                    },
                  ),
          ),

          // 输入栏
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 20),
                  onPressed: _loading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 预处理 DeepSeek 回复中的数学公式，使 Markdown 能正确显示
  /// 将 $$...$$ 替换为代码块，将 $...$ 替换为行内代码
  String _preprocessContent(String content) {
    // 先处理 $$...$$（块级公式），替换为 fenced code block
    var result = content.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (match) => '```math\n${match.group(1)}\n```',
    );
    // 再处理 $...$（行内公式），替换为行内代码
    // 注意：避免匹配到已被替换的 $$...$$
    result = result.replaceAllMapped(
      RegExp(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)'),
      (match) {
        // 确保不被 ``` 包裹的内容干扰
        final text = match.group(1)!;
        if (text.contains('\n')) return match.group(0)!;
        return '`\$$text\$`';
      },
    );
    return result;
  }

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isUser ? Colors.white : null;
    final bubbleWidth = MediaQuery.of(context).size.width * 0.78;

    // 预处理：Markdown 渲染 + 数学公式转化为代码块
    final displayContent = isUser ? msg.content : _preprocessContent(msg.content);

    // 构建 Markdown 样式表
    final mdStyle = MarkdownStyleSheet(
      p: TextStyle(fontSize: 15, height: 1.4, color: textColor),
      h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4, color: textColor),
      h2: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4, color: textColor),
      h3: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4, color: textColor),
      code: TextStyle(
        fontSize: 13,
        height: 1.3,
        backgroundColor: isUser
            ? Colors.white.withOpacity(0.15)
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
        color: textColor,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: isUser
            ? Colors.white.withOpacity(0.1)
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      listBullet: TextStyle(fontSize: 15, height: 1.4, color: textColor),
      strong: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.4, color: textColor),
      em: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, height: 1.4, color: textColor),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isUser ? Colors.white.withOpacity(0.5) : Colors.grey.shade400,
            width: 3,
          ),
        ),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isUser ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      del: TextStyle(fontSize: 15, height: 1.4, decoration: TextDecoration.lineThrough, color: textColor),
      tableBody: TextStyle(fontSize: 13, height: 1.3, color: textColor),
      tableHead: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.3, color: textColor),
      tableBorder: TableBorder.all(
        color: isUser ? Colors.white.withOpacity(0.3) : Colors.grey.shade300,
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: bubbleWidth),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 用户消息用纯文本，助手消息用 Markdown 渲染
            isUser
                ? SelectableText(
                    displayContent,
                    style: TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
                  )
                : Markdown(
                    data: displayContent,
                    selectable: true,
                    shrinkWrap: true,
                    styleSheet: mdStyle,
                    padding: EdgeInsets.zero,
                  ),
            const SizedBox(height: 4),
            Text(
              '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                color: isUser ? Colors.white60 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}