import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_helper.dart' as notif;
import 'chat_detail_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with WidgetsBindingObserver {
  List<dynamic> _conversations = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  int _totalUnread = 0;
  int _prevTotalUnread = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConversations();
    // 每3秒自动刷新会话列表
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _silentRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _silentRefresh();
    }
  }

  Future<void> _loadConversations() async {
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.getConversations();
    if (!mounted) return;
    if (res.isSuccess && res.data is List) {
      _updateConversations(res.data);
      setState(() { _loading = false; });
    } else {
      setState(() { _error = res.message; _loading = false; });
    }
  }

  Future<void> _silentRefresh() async {
    final res = await ApiService.getConversations();
    if (!mounted) return;
    if (res.isSuccess && res.data is List) {
      _updateConversations(res.data);
    }
  }

  void _updateConversations(List<dynamic> data) {
    _prevTotalUnread = _totalUnread;
    int newTotal = 0;
    for (var conv in data) {
      newTotal += (conv['unread_count'] ?? 0) as int;
    }
    _totalUnread = newTotal;

    // 新消息到达时播放提示音和显示浏览器通知
    if (_totalUnread > _prevTotalUnread && _prevTotalUnread >= 0) {
      _playNotificationSound();
      // 找到有新消息的会话，显示浏览器通知
      if (kIsWeb) {
        for (var conv in data) {
          final unread = conv['unread_count'] ?? 0;
          if (unread > 0) {
            final name = conv['name'] ?? '新消息';
            final lastMsg = conv['last_message'] ?? '您有新消息';
            _showBrowserNotification(name, lastMsg);
            break;
          }
        }
      }
    }

    setState(() { _conversations = data; });
  }

  void _playNotificationSound() {
    // 播放Web端提示音
    try {
      notif.webPlayNotificationSound();
    } catch (_) {}
  }

  void _showBrowserNotification(String title, String body) {
    try {
      notif.webShowBrowserNotification(title, body);
    } catch (_) {}
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
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));
              },
            ),
            ListTile(
              leading: Icon(isMuted ? Icons.notifications : Icons.notifications_off, color: AppColors.warning),
              title: Text(isMuted ? '取消免打扰' : '消息免打扰'),
              onTap: () async {
                Navigator.pop(ctx);
                final res = await ApiService.muteConversation(conv['id'], !isMuted);
                if (res.isSuccess) _loadConversations();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_read, color: AppColors.success),
              title: const Text('标记已读'),
              onTap: () async {
                Navigator.pop(ctx);
                // 进入会话会自动标记已读
                _loadConversations();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('删除会话', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteConversation(conv);
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _confirmDeleteConversation(dynamic conv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除会话'),
        content: Text('确定要删除与"${conv['name'] ?? '未命名'}"的会话吗？\n删除后聊天记录将不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // TODO: 调用删除会话API
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('会话已删除'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)));
              _loadConversations();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('消息'),
          if (_totalUnread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
              child: Text('$_totalUnread', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.search), tooltip: '搜索', onPressed: _showSearchDialog),
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
                const SizedBox(height: 8),
                const Text('点击右上角"+"发起新的聊天', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(builder: (ctx, setDialogState) {
          final filtered = _conversations.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final lastMsg = (c['last_message'] ?? '').toString().toLowerCase();
            return name.contains(query.toLowerCase()) || lastMsg.contains(query.toLowerCase());
          }).toList();
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              width: 400, height: 480,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  child: Row(children: [
                    Expanded(child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '搜索会话...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (v) => setDialogState(() { query = v; }),
                    )),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                    ? const Center(child: Text('无匹配结果', style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final c = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: c['type'] == 'group' ? AppColors.info.withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
                              child: Text((c['name'] ?? '?')[0], style: TextStyle(color: c['type'] == 'group' ? AppColors.info : AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                            title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(c['last_message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatDetailPage(conversationId: c['id'], title: c['name'] ?? ''),
                              )).then((_) => _loadConversations());
                            },
                          );
                        },
                      ),
                ),
              ]),
            ),
          );
        });
      },
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

    // 消息预览：群聊显示发送者名字
    String displayMsg = lastMsg;
    if (lastMsg.isEmpty) {
      displayMsg = '[暂无消息]';
    } else if (isGroup && conv['last_sender_name'] != null && conv['last_sender_name'].toString().isNotEmpty) {
      displayMsg = '${conv['last_sender_name']}: $lastMsg';
    }

    return Dismissible(
      key: Key(conv['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        _showConversationActions(conv);
        return false;
      },
      child: InkWell(
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
                child: isGroup
                  ? const Icon(Icons.group, color: AppColors.info, size: 22)
                  : Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
              if (isPinned) Positioned(
                left: 0, top: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.push_pin, size: 10, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Row(children: [
                    Flexible(child: Text(name, style: TextStyle(fontSize: 16, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                    if (isMuted) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.notifications_off, size: 14, color: AppColors.textSecondary)),
                  ])),
                  Text(lastTime, style: TextStyle(fontSize: 12, color: unread > 0 ? AppColors.primary : AppColors.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(
                    displayMsg,
                    style: TextStyle(fontSize: 13, color: unread > 0 ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
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
  List<dynamic> _filteredContacts = [];
  bool _loading = true;
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final res = await ApiService.getContacts();
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(() { _contacts = res.data['contacts'] ?? []; _filteredContacts = List.from(_contacts); _loading = false; });
    } else {
      setState(() { _loading = false; });
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_contacts);
      } else {
        _filteredContacts = _contacts.where((c) {
          final name = (c['nickname'] ?? c['username'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
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
        width: 420, height: 560,
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
                // 私聊Tab - 带搜索
                Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索联系人...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: _filterContacts,
                    ),
                  ),
                  Expanded(
                    child: _filteredContacts.isEmpty
                      ? const Center(child: Text('暂无联系人', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          itemCount: _filteredContacts.length,
                          itemBuilder: (_, i) {
                            final c = _filteredContacts[i];
                            final isOnline = c['online_status'] == 'online';
                            return ListTile(
                              leading: Stack(children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.15),
                                  child: Text((c['nickname'] ?? '?')[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                                ),
                                Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? AppColors.online : AppColors.offline, border: Border.all(color: Colors.white, width: 1.5)))),
                              ]),
                              title: Text(c['nickname'] ?? c['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text('${c['department_name'] ?? ''} ${c['position'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                                child: const Text('发消息', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                              onTap: () => _startPrivateChat(c),
                            );
                          },
                        ),
                  ),
                ]),
                // 创建群聊Tab
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    TextField(
                      controller: _groupNameController,
                      decoration: InputDecoration(
                        labelText: '群名称',
                        hintText: '请输入群名称',
                        prefixIcon: const Icon(Icons.group),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text('选择成员 (${_selectedMembers.length})', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _selectedMembers.isEmpty ? null : _createGroup,
                        icon: const Icon(Icons.group_add, size: 18),
                        label: const Text('创建群聊'),
                        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      ),
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
                          subtitle: Text('${c['department_name'] ?? ''} ${c['position'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12)),
                          secondary: CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withOpacity(0.15),
                            child: Text((c['nickname'] ?? '?')[0], style: const TextStyle(color: AppColors.primary, fontSize: 14))),
                          controlAffinity: ListTileControlAffinity.trailing,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
