import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../services/mock_data.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final conversations = MockData.conversations;
    // 置顶排序：isPinned在前，然后按时间倒序
    conversations.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conv = conversations[index];
          return _ConversationTile(conversation: conv);
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: conversation.isPinned ? AppColors.background : AppColors.cardBg,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: conversation.isGroup
                  ? AppColors.info.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.15),
              child: Icon(
                conversation.isGroup ? Icons.group : Icons.person,
                color: conversation.isGroup ? AppColors.info : AppColors.primary,
                size: 22,
              ),
            ),
            if (conversation.unreadCount > 0)
              Positioned(
                right: 0, top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.unreadBadge,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 14),
                  child: Text(
                    conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(conversation.lastMessageTime),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (conversation.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                ),
              Expanded(
                child: Text(
                  conversation.lastMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: conversation.unreadCount > 0 ? AppColors.textPrimary.withValues(alpha: 0.7) : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              conversationId: conversation.id,
              title: conversation.name,
              isGroup: conversation.isGroup,
            ),
          ));
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}
