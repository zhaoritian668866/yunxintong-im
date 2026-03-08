import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../services/mock_data.dart';

class ChatDetailPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final bool isGroup;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    required this.title,
    this.isGroup = false,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late List<Message> _messages;

  @override
  void initState() {
    super.initState();
    _messages = MockData.getChatMessages(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        senderName: '我',
        content: text,
        timestamp: DateTime.now(),
        isMe: true,
      ));
    });
    _messageController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (widget.isGroup)
              const Text('(28)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _MessageBubble(message: msg, isGroup: widget.isGroup);
              },
            ),
          ),
          // 输入栏
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 26),
            onPressed: () => _showAttachMenu(),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.textSecondary, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 24,
          runSpacing: 20,
          children: [
            _buildAttachItem(Icons.photo_library, '相册', AppColors.success),
            _buildAttachItem(Icons.camera_alt, '拍摄', AppColors.primary),
            _buildAttachItem(Icons.insert_drive_file, '文件', AppColors.warning),
            _buildAttachItem(Icons.location_on, '位置', AppColors.error),
            _buildAttachItem(Icons.videocam, '视频通话', AppColors.info),
            _buildAttachItem(Icons.person_add, '名片', AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachItem(IconData icon, String label, Color color) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isGroup;

  const _MessageBubble({required this.message, this.isGroup = false});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0] : '?',
                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isGroup)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(message.senderName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.chatBubbleSent : AppColors.chatBubbleReceived,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: _buildContent(isMe),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0] : '我',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(bool isMe) {
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    switch (message.type) {
      case MessageType.text:
        return Text(message.content, style: TextStyle(fontSize: 15, color: textColor, height: 1.4));
      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: isMe ? Colors.white70 : AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(message.fileName ?? '文件', style: TextStyle(fontSize: 14, color: textColor))),
          ],
        );
      case MessageType.voice:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: isMe ? Colors.white : AppColors.primary, size: 22),
            const SizedBox(width: 4),
            Container(width: 80, height: 3, decoration: BoxDecoration(color: (isMe ? Colors.white : AppColors.primary).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('${message.voiceDuration}"', style: TextStyle(fontSize: 13, color: textColor)),
          ],
        );
      case MessageType.image:
        return Container(
          width: 180, height: 120,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image, color: AppColors.textSecondary, size: 40),
        );
      case MessageType.system:
        return Text(message.content, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary));
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
