import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class ChatDetailPage extends StatefulWidget {
  final String conversationId;
  final String conversationName;
  final String conversationType;

  const ChatDetailPage({super.key, required this.conversationId, required this.conversationName, required this.conversationType});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMessages();
  }

  Future<void> _loadProfile() async {
    final res = await ApiService.userProfile();
    if (res.isSuccess && res.data != null) _currentUserId = res.data['id'];
  }

  Future<void> _loadMessages() async {
    final res = await ApiService.getMessages(widget.conversationId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          // 后端返回 { total, list: [...] }，消息已按时间正序排列
          final rawData = res.data;
          if (rawData is Map) {
            _messages = List<Map<String, dynamic>>.from(rawData['list'] ?? rawData['messages'] ?? []);
          } else if (rawData is List) {
            _messages = List<Map<String, dynamic>>.from(rawData);
          }
        }
      });
      _scrollToBottom();
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
    if (text.isEmpty) return;
    _msgController.clear();
    setState(() {
      _messages.add({'id': 'temp_${DateTime.now().millisecondsSinceEpoch}', 'content': text, 'type': 'text', 'sender_id': _currentUserId, 'sender_name': '我', 'created_at': DateTime.now().toIso8601String()});
    });
    _scrollToBottom();
    final res = await ApiService.sendMessage(widget.conversationId, text);
    if (res.isSuccess) _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => Navigator.pop(context)),
        title: Column(children: [
          Text(widget.conversationName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          if (widget.conversationType == 'group') const Text('群聊', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary), onPressed: () {})],
      ),
      body: Column(children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(child: Text('暂无消息，发送第一条消息吧', style: TextStyle(color: Colors.grey.shade400)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                    ),
        ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _currentUserId;
    final content = msg['content'] ?? '';
    final senderName = msg['sender_name'] ?? '';
    final type = msg['type'] ?? 'text';
    final isRecalled = msg['is_recalled'] == 1;
    final time = msg['created_at'] ?? '';
    String timeStr = '';
    try { final dt = DateTime.parse(time); timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'; } catch (_) {}

    if (isRecalled) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('$senderName 撤回了一条消息', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))));
    }
    if (type == 'system') {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
        child: Text(content, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      )));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text(senderName.isNotEmpty ? senderName[0] : '?', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
          ],
          Flexible(child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && widget.conversationType == 'group')
                Padding(padding: const EdgeInsets.only(bottom: 4, left: 4), child: Text(senderName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              GestureDetector(
                onLongPress: isMe ? () => _showMessageMenu(msg) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.chatBubbleSent : AppColors.chatBubbleReceived,
                    borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: Text(content, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.4)),
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 4, left: 4, right: 4), child: Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            ],
          )),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Text(senderName.isNotEmpty ? senderName[0] : '我', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
          ],
        ],
      ),
    );
  }

  void _showMessageMenu(Map<String, dynamic> msg) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.copy), title: const Text('复制'), onTap: () { Navigator.pop(ctx); }),
      ListTile(leading: const Icon(Icons.replay), title: const Text('撤回'), onTap: () async { Navigator.pop(ctx); final r = await ApiService.recallMessage(msg['id']); if (r.isSuccess) _loadMessages(); }),
    ])));
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: AppColors.cardBg, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 26), onPressed: _showAttachMenu),
        Expanded(child: Container(
          decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(20)),
          child: TextField(
            controller: _msgController,
            decoration: const InputDecoration(hintText: '输入消息...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            maxLines: 4, minLines: 1, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage(),
          ),
        )),
        const SizedBox(width: 8),
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendMessage)),
      ]),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(padding: const EdgeInsets.all(24), child: Wrap(spacing: 24, runSpacing: 20, children: [
        _buildAttachItem(Icons.photo_library, '相册', AppColors.success),
        _buildAttachItem(Icons.camera_alt, '拍摄', AppColors.primary),
        _buildAttachItem(Icons.insert_drive_file, '文件', AppColors.warning),
        _buildAttachItem(Icons.location_on, '位置', AppColors.error),
        _buildAttachItem(Icons.videocam, '视频通话', AppColors.info),
        _buildAttachItem(Icons.person_add, '名片', AppColors.textSecondary),
      ])));
  }

  Widget _buildAttachItem(IconData icon, String label, Color color) {
    return SizedBox(width: 72, child: Column(children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 26)),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]));
  }

  @override
  void dispose() { _msgController.dispose(); _scrollController.dispose(); super.dispose(); }
}
