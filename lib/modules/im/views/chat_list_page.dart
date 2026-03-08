import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final res = await ApiService.getConversations();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          // data直接是数组（后端返回格式）
          final rawData = res.data;
          if (rawData is List) {
            _conversations = List<Map<String, dynamic>>.from(rawData);
          } else if (rawData is Map) {
            _conversations = List<Map<String, dynamic>>.from(rawData['conversations'] ?? rawData['list'] ?? []);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('消息'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showNewChatDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('暂无消息', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('开始一段新的对话吧', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) => _buildChatItem(_conversations[index]),
                  ),
                ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> conv) {
    final name = conv['name'] ?? '未知';
    final lastMsg = conv['last_message'] ?? '';
    final unread = conv['unread_count'] ?? 0;
    final isPinned = conv['is_pinned'] == 1;
    final type = conv['type'] ?? 'single';
    final time = conv['last_message_at'] ?? conv['last_message_time'] ?? '';
    String timeStr = '';
    if (time.isNotEmpty) {
      try {
        final dt = DateTime.parse(time);
        final now = DateTime.now();
        if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
          timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          timeStr = '${dt.month}/${dt.day}';
        }
      } catch (_) {}
    }

    return Container(
      color: isPinned ? AppColors.background : AppColors.cardBg,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: type == 'group' ? AppColors.info.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
              child: Icon(type == 'group' ? Icons.group : Icons.person, color: type == 'group' ? AppColors.info : AppColors.primary, size: 22),
            ),
            if (unread > 0)
              Positioned(right: 0, top: 0, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: AppColors.unreadBadge, borderRadius: BorderRadius.circular(10)),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 14),
                child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              )),
          ],
        ),
        title: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
          Text(timeStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            if (isPinned) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.push_pin, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
            Expanded(child: Text(lastMsg, style: TextStyle(fontSize: 13, color: unread > 0 ? AppColors.textPrimary.withValues(alpha: 0.7) : AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          ]),
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(
            conversationId: conv['id'],
            conversationName: name,
            conversationType: type,
          ))).then((_) => _loadConversations());
        },
        onLongPress: () => _showConversationMenu(conv),
      ),
    );
  }

  void _showConversationMenu(Map<String, dynamic> conv) {
    final isPinned = conv['is_pinned'] == 1;
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin), title: Text(isPinned ? '取消置顶' : '置顶'), onTap: () async {
          Navigator.pop(ctx);
          await ApiService.pinConversation(conv['id'], !isPinned);
          _loadConversations();
        }),
        ListTile(leading: const Icon(Icons.notifications_off_outlined), title: const Text('免打扰'), onTap: () async {
          Navigator.pop(ctx);
          await ApiService.muteConversation(conv['id'], true);
          _loadConversations();
        }),
      ]),
    ));
  }

  void _showNewChatDialog() {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('发起聊天', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ListTile(leading: const Icon(Icons.person_add), title: const Text('发起单聊'), onTap: () { Navigator.pop(ctx); _startNewChat('private'); }),
        ListTile(leading: const Icon(Icons.group_add), title: const Text('发起群聊'), onTap: () { Navigator.pop(ctx); _startNewChat('group'); }),
      ]),
    ));
  }

  Future<void> _startNewChat(String type) async {
    final res = await ApiService.getContacts();
    if (!res.isSuccess || res.data == null || !mounted) return;
    final contacts = List<Map<String, dynamic>>.from(res.data['contacts'] ?? []);
    final selected = <String>[];
    final nameCtrl = TextEditingController(text: type == 'group' ? '新群组' : '');

    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => AlertDialog(
      title: Text(type == 'private' ? '选择联系人' : '创建群聊'),
      content: SizedBox(width: double.maxFinite, height: 400, child: Column(children: [
        if (type != 'private') ...[
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '群名称', border: OutlineInputBorder())),
          const SizedBox(height: 12),
        ],
        Expanded(child: ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (_, i) {
            final c = contacts[i];
            final isSelected = selected.contains(c['id']);
            return CheckboxListTile(
              value: isSelected,
              title: Text(c['nickname'] ?? c['username'] ?? ''),
              subtitle: Text(c['position'] ?? '', style: const TextStyle(fontSize: 12)),
              onChanged: (v) { setS(() { if (v == true) { if (type == 'private') selected.clear(); selected.add(c['id']); } else selected.remove(c['id']); }); },
            );
          },
        )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: selected.isEmpty ? null : () async {
          Navigator.pop(ctx);
          final actualType = type == 'private' ? 'private' : type;
          final r = await ApiService.createConversation(actualType, memberIds: selected, name: type == 'group' ? nameCtrl.text : null);
          if (r.isSuccess) _loadConversations();
        }, child: const Text('确定')),
      ],
    )));
  }
}
