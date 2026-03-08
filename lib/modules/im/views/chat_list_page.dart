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
  List<dynamic> _conversations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.getConversations();
    if (!mounted) return;
    if (res.isSuccess && res.data is List) {
      setState(() { _conversations = res.data; _loading = false; });
    } else {
      setState(() { _error = res.message; _loading = false; });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
      if (diff.inDays < 1) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff.inDays == 1) return '昨天';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      return '${dt.month}/${dt.day}';
    } catch (_) { return ''; }
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _NewChatDialog(
        onCreated: (convId, convName) {
          Navigator.pop(ctx);
          _loadConversations();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatDetailPage(conversationId: convId, title: convName),
          )).then((_) => _loadConversations());
        },
      ),
    );
  }

  void _showConversationActions(dynamic conv) {
    final isPinned = (conv['is_pinned'] ?? 0) == 1;
    final isMuted = (conv['is_muted'] ?? 0) == 1;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: AppColors.primary),
              title: Text(isPinned ? '取消置顶' : '置顶会话'),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await ApiService.pinConversation(conv['id'], !isPinned);
                if (res.isSuccess) _loadConversations();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), behavior: SnackBarBehavior.floating));
              },
            ),
            ListTile(
              leading: Icon(isMuted ? Icons.notifications : Icons.notifications_off, color: AppColors.warning),
              title: Text(isMuted ? '取消免打扰' : '消息免打扰'),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await ApiService.muteConversation(conv['id'], !isMuted);
                if (res.isSuccess) _loadConversations();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), behavior: SnackBarBehavior.floating));
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.add_comment_outlined), tooltip: '发起聊天', onPressed: _showNewChatDialog),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadConversations, child: const Text('重试')),
            ]))
          : _conversations.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text('暂无会话', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: _showNewChatDialog, icon: const Icon(Icons.add), label: const Text('发起聊天')),
              ]))
            : RefreshIndicator(
                onRefresh: _loadConversations,
                child: ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                  itemBuilder: (context, index) => _buildConversationTile(_conversations[index]),
                ),
              ),
    );
  }

  Widget _buildConversationTile(dynamic conv) {
    final name = conv['name'] ?? '未命名';
    final lastMsg = conv['last_message'] ?? '';
    final lastTime = _formatTime(conv['last_message_at']?.toString());
    final unread = conv['unread_count'] ?? 0;
    final isPinned = (conv['is_pinned'] ?? 0) == 1;
    final isMuted = (conv['is_muted'] ?? 0) == 1;
    final isGroup = conv['type'] == 'group';
    final isOnline = conv['peer_online'] == 'online';

    String displayMsg = lastMsg;
    if (isGroup && conv['last_sender_name'] != null && conv['last_sender_name'].toString().isNotEmpty) {
      displayMsg = '${conv['last_sender_name']}: $lastMsg';
    }

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatDetailPage(conversationId: conv['id'], title: name),
        )).then((_) => _loadConversations());
      },
      onLongPress: () => _showConversationActions(conv),
      child: Container(
        color: isPinned ? AppColors.primary.withOpacity(0.04) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isGroup ? AppColors.info.withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
              child: Text(
                name.isNotEmpty ? name[0] : '?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isGroup ? AppColors.info : AppColors.primary),
              ),
            ),
            if (!isGroup) Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.online : AppColors.offline,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Row(children: [
                  Flexible(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                  if (isMuted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.notifications_off, size: 14, color: AppColors.textSecondary)),
                ])),
                Text(lastTime, style: TextStyle(fontSize: 12, color: unread > 0 ? AppColors.primary : AppColors.textSecondary)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text(displayMsg, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (unread > 0) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: isMuted ? AppColors.textSecondary : AppColors.unreadBadge, borderRadius: BorderRadius.circular(10)),
                  child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          )),
        ]),
      ),
    );
  }
}

class _NewChatDialog extends StatefulWidget {
  final Function(String convId, String convName) onCreated;
  const _NewChatDialog({required this.onCreated});
  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _contacts = [];
  bool _loading = true;
  final _groupNameController = TextEditingController();
  final Set<String> _selectedMembers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContacts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final res = await ApiService.getContacts();
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(() { _contacts = res.data['contacts'] ?? []; _loading = false; });
    } else {
      setState(() { _loading = false; });
    }
  }

  Future<void> _startPrivateChat(dynamic contact) async {
    final res = await ApiService.createConversation('private', memberIds: [contact['id']]);
    if (res.isSuccess && res.data != null) {
      widget.onCreated(res.data['id'], contact['nickname'] ?? contact['username']);
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入群名称'), behavior: SnackBarBehavior.floating));
      return;
    }
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择至少一个成员'), behavior: SnackBarBehavior.floating));
      return;
    }
    final res = await ApiService.createConversation('group', name: _groupNameController.text.trim(), memberIds: _selectedMembers.toList());
    if (res.isSuccess && res.data != null) {
      widget.onCreated(res.data['id'], _groupNameController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400, height: 520,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(children: [
              const Text('发起聊天', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          TabBar(controller: _tabController, tabs: const [Tab(text: '私聊'), Tab(text: '创建群聊')],
            labelColor: AppColors.primary, unselectedLabelColor: AppColors.textSecondary, indicatorColor: AppColors.primary),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabController, children: [
                _contacts.isEmpty
                  ? const Center(child: Text('暂无联系人', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (_, i) {
                        final c = _contacts[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.15),
                            child: Text((c['nickname'] ?? '?')[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                          title: Text(c['nickname'] ?? c['username'] ?? ''),
                          subtitle: Text(c['department_name'] ?? c['position'] ?? '', style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.primary),
                          onTap: () => _startPrivateChat(c),
                        );
                      },
                    ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    TextField(controller: _groupNameController, decoration: const InputDecoration(labelText: '群名称', hintText: '请输入群名称', prefixIcon: Icon(Icons.group))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text('选择成员 (${_selectedMembers.length})', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      ElevatedButton(onPressed: _createGroup, child: const Text('创建群聊')),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(child: ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (_, i) {
                        final c = _contacts[i];
                        final selected = _selectedMembers.contains(c['id']);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (v) { setState(() { if (v == true) _selectedMembers.add(c['id']); else _selectedMembers.remove(c['id']); }); },
                          title: Text(c['nickname'] ?? c['username'] ?? ''),
                          subtitle: Text(c['department_name'] ?? '', style: const TextStyle(fontSize: 12)),
                          secondary: CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withOpacity(0.15),
                            child: Text((c['nickname'] ?? '?')[0], style: const TextStyle(color: AppColors.primary, fontSize: 14))),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    )),
                  ]),
                ),
              ]),
          ),
        ]),
      ),
    );
  }
}
