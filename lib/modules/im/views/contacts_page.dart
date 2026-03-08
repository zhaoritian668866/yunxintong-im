import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';
import 'chat_detail_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final res = await ApiService.getContacts();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          _contacts = List<Map<String, dynamic>>.from(res.data['contacts'] ?? []);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('通讯录'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadContacts,
              child: ListView(
                children: [
                  Container(
                    color: AppColors.cardBg,
                    child: Column(children: [
                      _buildQuickEntry(Icons.group, '群组', AppColors.primary),
                      const Divider(height: 0.5, indent: 56),
                      _buildQuickEntry(Icons.business, '部门', AppColors.success),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('联系人 (${_contacts.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                  ..._contacts.map((c) {
                    final name = c['nickname'] ?? c['username'] ?? '';
                    final position = c['position'] ?? '';
                    final dept = c['department_name'] ?? '';
                    final isOnline = c['online_status'] == 'online';
                    return Container(
                      color: AppColors.cardBg,
                      child: ListTile(
                        leading: Stack(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                          Positioned(right: 0, bottom: 0, child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: isOnline ? AppColors.online : AppColors.offline,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.cardBg, width: 1.5),
                            ),
                          )),
                        ]),
                        title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        subtitle: Text('${dept.isNotEmpty ? '$dept | ' : ''}$position', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.primary),
                          onPressed: () => _startChat(c),
                        ),
                        onTap: () => _showContactDetail(c),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickEntry(IconData icon, String title, Color color) {
    return ListTile(
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
      onTap: () {},
    );
  }

  Future<void> _startChat(Map<String, dynamic> contact) async {
    final res = await ApiService.createConversation('private', memberIds: [contact['id']]);
    if (res.isSuccess && res.data != null && mounted) {
      // 后端直接返回 { id: "xxx" } 或 { id: "xxx", is_existing: true }
      final convId = res.data is Map ? (res.data['id'] ?? '') : '';
      if (convId.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(
          conversationId: convId,
          conversationName: contact['nickname'] ?? contact['username'] ?? '',
          conversationType: 'private',
        )));
      }
    }
  }

  void _showContactDetail(Map<String, dynamic> c) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 36, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text((c['nickname'] ?? '?')[0], style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold))),
        const SizedBox(height: 12),
        Text(c['nickname'] ?? c['username'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(c['position'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        if (c['phone'] != null) Text(c['phone'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (c['email'] != null) Text(c['email'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _startChat(c); }, icon: const Icon(Icons.chat), label: const Text('发消息'))),
        const SizedBox(height: 12),
      ])));
  }
}
