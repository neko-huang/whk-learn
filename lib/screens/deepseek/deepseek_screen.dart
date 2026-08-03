import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DeepSeek 聊天消息
class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime time;

  _ChatMessage({required this.role, required this.content, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

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
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      role: 'assistant',
      content: '你好！我是 DeepSeek AI 助手，有什么可以帮助你的吗？',
    ));
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('deepseek_api_key');
    if (mounted) {
      setState(() => _apiKey = key);
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
      if (mounted) Navigator.pop(context); // 没输入就返回
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_api_key', result);
    if (mounted) setState(() => _apiKey = result);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    if (_apiKey == null || _apiKey!.isEmpty) {
      _showKeyDialog();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final reply = await _callDeepSeek(_messages.map((m) => m.toJson()).toList());
      if (mounted) {
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

  Future<String> _callDeepSeek(List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final model = prefs.getString('deepseek_model') ?? 'deepseek-chat';
    final reasoningEffort = prefs.getString('deepseek_reasoning_effort') ?? 'off';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);

    try {
      // 只保留最近 20 条控制上下文长度
      if (messages.length > 20) {
        messages = [messages.first, ...messages.sublist(messages.length - 19)];
      }

      final body = <String, dynamic>{
        'model': model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 4096,
      };

      // 思考等级：仅在开启时传递 reasoning_effort
      if (reasoningEffort != 'off') {
        body['reasoning_effort'] = reasoningEffort;
      }

      final req = await client.postUrl(Uri.parse('https://api.deepseek.com/v1/chat/completions'));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Authorization', 'Bearer $_apiKey');
      req.write(jsonEncode(body));

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DeepSeek'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            tooltip: '设置 API Key',
            onPressed: _showKeyDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '清空对话',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(_ChatMessage(
                  role: 'assistant',
                  content: '对话已清空，有什么可以帮助你的吗？',
                ));
              });
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

  Widget _buildBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
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
          children: [
            SelectableText(
              msg.content,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isUser ? Colors.white : null,
              ),
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