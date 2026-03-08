import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class ChatDetailPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final String? conversationName;
  final String? conversationType;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    this.title = '',
    this.conversationName,
    this.conversationType,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String _currentUserId = '';
  Timer? _refreshTimer;

  String get _displayTitle => widget.title.isNotEmpty ? widget.title : (widget.conversationName ?? '');

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final res = await ApiService.userProfile();
    if (res.isSuccess && res.data != null && mounted) {
      setState(() { _currentUserId = res.data['id'] ?? ''; });
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; });
    final res = await ApiService.getMessages(widget.conversationId);
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      final rawData = res.data;
      List list = [];
      if (rawData is Map) {
        list = rawData['list'] ?? rawData['messages'] ?? [];
      } else if (rawData is List) {
        list = rawData;
      }
      final oldLen = _messages.length;
      setState(() { _messages = list; _loading = false; });
      if (!silent || list.length > oldLen) _scrollToBottom();
    } else {
      setState(() { _loading = false; });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; });
    _msgController.clear();
    final res = await ApiService.sendMessage(widget.conversationId, text);
    if (!mounted) return;
    if (res.isSuccess && res.data != null) {
      setState(() { _messages.add(res.data); _sending = false; });
      _scrollToBottom();
    } else {
      setState(() { _sending = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发送失败: ${res.message}'), behavior: SnackBarBehavior.floating));
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final dt = DateTime.parse(timeStr);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text(_displayTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _messages.isEmpty
              ? Center(child: Text('暂无消息，发送第一条消息吧', style: TextStyle(color: Colors.grey.shade400)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(_messages[index], index),
                ),
        ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildMessageBubble(dynamic msg, int index) {
    final isMe = msg['sender_id'] == _currentUserId;
    final content = msg['content'] ?? '';
    final senderName = msg['sender_name'] ?? '';
    final isRecalled = msg['is_recalled'] == 1;
    final time = msg['created_at'] ?? '';
    String timeStr = '';
    try { final dt = DateTime.parse(time); timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'; } catch (_) {}

    // 时间分隔
    bool showTime = false;
    if (index == 0) {
      showTime = true;
    } else {
      try {
        final prev = DateTime.parse(_messages[index - 1]['created_at']);
        final curr = DateTime.parse(msg['created_at']);
        showTime = curr.difference(prev).inMinutes > 5;
      } catch (_) {}
    }

    if (isRecalled) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('${isMe ? "你" : senderName} 撤回了一条消息', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))));
    }

    return Column(children: [
      if (showTime) Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
          child: Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withOpacity(0.15), child: Text(senderName.isNotEmpty ? senderName[0] : '?', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
            ],
            Flexible(child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 2, left: 4), child: Text(senderName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                GestureDetector(
                  onLongPress: () => _showMessageMenu(msg, isMe),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.chatBubbleSent : AppColors.chatBubbleReceived,
                      borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: Text(content, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.4)),
                  ),
                ),
              ],
            )),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: const Text('我', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
            ],
          ],
        ),
      ),
    ]);
  }

  void _showMessageMenu(dynamic msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.copy, color: AppColors.primary),
            title: const Text('复制'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg['content'] ?? ''));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'), behavior: SnackBarBehavior.floating));
            },
          ),
          if (isMe) ListTile(
            leading: const Icon(Icons.undo, color: AppColors.warning),
            title: const Text('撤回消息'),
            onTap: () async {
              Navigator.pop(ctx);
              final r = await ApiService.recallMessage(msg['id']);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message), behavior: SnackBarBehavior.floating));
              if (r.isSuccess) _loadMessages(silent: true);
            },
          ),
        ]),
      )),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: AppColors.cardBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Row(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20)),
          child: TextField(
            controller: _msgController,
            decoration: const InputDecoration(hintText: '输入消息...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            maxLines: 4, minLines: 1, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage(),
          ),
        )),
        const SizedBox(width: 8),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: IconButton(
            icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 18),
            onPressed: _sending ? null : _sendMessage,
          ),
        ),
      ]),
    );
  }
}
