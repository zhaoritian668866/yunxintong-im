import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class EnterpriseChatRecordsPage extends StatefulWidget {
  const EnterpriseChatRecordsPage({super.key});

  @override
  State<EnterpriseChatRecordsPage> createState() => _EnterpriseChatRecordsPageState();
}

class _EnterpriseChatRecordsPageState extends State<EnterpriseChatRecordsPage> {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMessages = false;
  String _searchQuery = '';
  String? _selectedConvId;
  String _selectedConvName = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final res = await ApiService.enterpriseGetChatRecords(keyword: _searchQuery.isNotEmpty ? _searchQuery : null);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          final d = res.data;
          if (d is Map) {
            _conversations = List<Map<String, dynamic>>.from(d['list'] ?? d['conversations'] ?? []);
          } else if (d is List) {
            _conversations = List<Map<String, dynamic>>.from(d);
          }
        }
      });
    }
  }

  Future<void> _loadMessages(String convId) async {
    setState(() => _isLoadingMessages = true);
    final res = await ApiService.adminChatMessages(convId);
    if (mounted) {
      setState(() {
        _isLoadingMessages = false;
        if (res.isSuccess && res.data != null) {
          final d = res.data;
          if (d is Map) {
            _messages = List<Map<String, dynamic>>.from(d['list'] ?? d['messages'] ?? []);
          } else if (d is List) {
            _messages = List<Map<String, dynamic>>.from(d);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：会话列表
          SizedBox(
            width: 360,
            child: Container(
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: InputDecoration(hintText: '搜索会话...', prefixIcon: const Icon(Icons.search, size: 20), contentPadding: const EdgeInsets.symmetric(vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    onChanged: (v) { _searchQuery = v; _loadConversations(); },
                  ),
                ),
                Expanded(
                  child: _conversations.isEmpty
                      ? Center(child: Text('暂无会话记录', style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (_, i) {
                            final c = _conversations[i];
                            final isSelected = c['id'] == _selectedConvId;
                            final name = c['name'] ?? '私聊';
                            final type = c['type'] ?? 'private';
                            final msgCount = c['message_count'] ?? 0;
                            final memberCount = c['member_count'] ?? 0;
                            final lastMsg = c['last_message'] ?? '';
                            // 获取成员名称列表
                            String displayName = name;
                            if (type == 'private' && c['members'] != null) {
                              final members = List<Map<String, dynamic>>.from(c['members'] ?? []);
                              displayName = members.map((m) => m['nickname'] ?? m['username'] ?? '').join(' & ');
                            }
                            return Container(
                              color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: (type == 'group' ? AppColors.info : AppColors.primary).withValues(alpha: 0.15),
                                  child: Icon(type == 'group' ? Icons.group : Icons.person, color: type == 'group' ? AppColors.info : AppColors.primary, size: 20),
                                ),
                                title: Text(displayName, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (lastMsg.isNotEmpty) Text(lastMsg, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('$memberCount 人 | $msgCount 条消息', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ]),
                                onTap: () {
                                  setState(() { _selectedConvId = c['id']; _selectedConvName = displayName; });
                                  _loadMessages(c['id']);
                                },
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('共 ${_conversations.length} 个会话', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 16),
          // 右侧：消息详情
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
              child: _selectedConvId == null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('选择左侧会话查看聊天记录', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    ]))
                  : Column(children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5)))),
                        child: Row(children: [
                          Text(_selectedConvName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${_messages.length} 条消息', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ]),
                      ),
                      Expanded(
                        child: _isLoadingMessages
                            ? const Center(child: CircularProgressIndicator())
                            : _messages.isEmpty
                                ? Center(child: Text('暂无消息', style: TextStyle(color: Colors.grey.shade500)))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _messages.length,
                                    itemBuilder: (_, i) => _buildMessageItem(_messages[i]),
                                  ),
                      ),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final senderName = msg['sender_name'] ?? '';
    final content = msg['content'] ?? '';
    final type = msg['type'] ?? 'text';
    final time = msg['created_at'] ?? '';
    final isRecalled = msg['is_recalled'] == 1;
    String timeStr = '';
    try {
      final dt = DateTime.parse(time);
      timeStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    if (isRecalled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(child: Text('$senderName 撤回了一条消息', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(senderName.isNotEmpty ? senderName[0] : '?', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(senderName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(timeStr, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: type == 'text'
                ? Text(content, style: const TextStyle(fontSize: 14))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_getTypeIcon(type), size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('[$type] $content', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ]),
          ),
        ])),
      ]),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'image': return Icons.image;
      case 'file': return Icons.attach_file;
      case 'voice': return Icons.mic;
      default: return Icons.text_fields;
    }
  }
}
