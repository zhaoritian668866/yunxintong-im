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
  List<dynamic> _contacts = [];
  List<dynamic> _departments = [];
  List<dynamic> _groups = [];
  List<dynamic> _filteredContacts = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() { _loading = true; });
    final res = await ApiService.getContacts();
    if (!mounted) return;
    if (res.isSuccess && res.data is Map) {
      setState(() {
        _contacts = res.data['contacts'] ?? [];
        _departments = res.data['departments'] ?? [];
        _groups = res.data['groups'] ?? [];
        _filteredContacts = List.from(_contacts);
        _loading = false;
      });
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
          final dept = (c['department_name'] ?? '').toString().toLowerCase();
          final pos = (c['position'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) || dept.contains(query.toLowerCase()) || pos.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _startChat(dynamic contact) async {
    final res = await ApiService.createConversation('private', memberIds: [contact['id']]);
    if (res.isSuccess && res.data != null && mounted) {
      final convId = res.data['id'] ?? '';
      if (convId.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(
          conversationId: convId, title: contact['nickname'] ?? contact['username'] ?? '',
        )));
      }
    }
  }

  // ==================== 添加好友功能 ====================
  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddContactDialog(
        onAdded: () {
          Navigator.pop(ctx);
          _loadContacts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('好友添加成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }

  void _showContactDetail(dynamic c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          CircleAvatar(radius: 40, backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text((c['nickname'] ?? '?')[0], style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text(c['nickname'] ?? c['username'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(shape: BoxShape.circle, color: c['online_status'] == 'online' ? AppColors.online : AppColors.offline)),
            Text(c['online_status'] == 'online' ? '在线' : '离线', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c['department_name'] != null && c['department_name'].toString().isNotEmpty) ...[
                _detailRow(Icons.business, '部门', c['department_name']),
                const SizedBox(height: 8),
              ],
              if (c['position'] != null && c['position'].toString().isNotEmpty) ...[
                _detailRow(Icons.work, '职位', c['position']),
                const SizedBox(height: 8),
              ],
              if (c['phone'] != null && c['phone'].toString().isNotEmpty) ...[
                _detailRow(Icons.phone, '电话', c['phone']),
                const SizedBox(height: 8),
              ],
              if (c['email'] != null && c['email'].toString().isNotEmpty)
                _detailRow(Icons.email, '邮箱', c['email']),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: SizedBox(height: 48, child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(ctx); _startChat(c); },
              icon: const Icon(Icons.chat),
              label: const Text('发消息', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ))),
            const SizedBox(width: 12),
            SizedBox(height: 48, child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmRemoveContact(c);
              },
              icon: const Icon(Icons.person_remove, size: 18, color: AppColors.error),
              label: const Text('删除', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _confirmRemoveContact(dynamic c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除联系人'),
        content: Text('确定要删除联系人"${c['nickname'] ?? c['username']}"吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.removeContact(c['id'].toString());
              if (res.isSuccess) {
                _loadContacts();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除联系人'), behavior: SnackBarBehavior.floating));
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: ${res.message}'), behavior: SnackBarBehavior.floating));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
    ]);
  }

  void _showGroupsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            const Text('群组', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ])),
          const Divider(height: 1),
          Expanded(child: _groups.isEmpty
            ? const Center(child: Text('暂无群组', style: TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                itemCount: _groups.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) {
                  final g = _groups[i];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: AppColors.info.withOpacity(0.15),
                      child: const Icon(Icons.group, color: AppColors.info)),
                    title: Text(g['name'] ?? '未命名群组', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${g['member_count'] ?? 0}人', style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(
                        conversationId: g['id'], title: g['name'] ?? '群聊',
                      )));
                    },
                  );
                },
              ),
          ),
        ]),
      ),
    );
  }

  void _showDepartmentsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            const Text('部门', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ])),
          const Divider(height: 1),
          Expanded(child: _departments.isEmpty
            ? const Center(child: Text('暂无部门', style: TextStyle(color: AppColors.textSecondary)))
            : ListView.separated(
                itemCount: _departments.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) {
                  final d = _departments[i];
                  final deptContacts = _contacts.where((c) => c['department_id'] == d['id']).toList();
                  return ExpansionTile(
                    leading: CircleAvatar(backgroundColor: AppColors.success.withOpacity(0.15),
                      child: const Icon(Icons.business, color: AppColors.success, size: 20)),
                    title: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${deptContacts.length}人', style: const TextStyle(fontSize: 12)),
                    children: deptContacts.map((c) => ListTile(
                      contentPadding: const EdgeInsets.only(left: 72, right: 16),
                      leading: CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text((c['nickname'] ?? '?')[0], style: const TextStyle(color: AppColors.primary, fontSize: 12))),
                      title: Text(c['nickname'] ?? '', style: const TextStyle(fontSize: 14)),
                      subtitle: Text(c['position'] ?? '', style: const TextStyle(fontSize: 12)),
                      onTap: () { Navigator.pop(ctx); _showContactDetail(c); },
                    )).toList(),
                  );
                },
              ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _showSearch
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(hintText: '搜索联系人...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
              onChanged: _filterContacts,
            )
          : const Text('通讯录'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) { _searchController.clear(); _filteredContacts = List.from(_contacts); }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '添加好友',
            onPressed: _showAddContactDialog,
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadContacts,
            child: ListView(children: [
              // 快捷入口
              Container(
                color: AppColors.cardBg,
                child: Column(children: [
                  _buildQuickEntry(Icons.person_add, '添加好友', AppColors.info, _showAddContactDialog),
                  const Divider(height: 0.5, indent: 56),
                  _buildQuickEntry(Icons.group, '群组 (${_groups.length})', AppColors.primary, _showGroupsList),
                  const Divider(height: 0.5, indent: 56),
                  _buildQuickEntry(Icons.business, '部门 (${_departments.length})', AppColors.success, _showDepartmentsList),
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('联系人 (${_filteredContacts.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
              if (_filteredContacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('暂无联系人', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddContactDialog,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('添加好友'),
                    ),
                  ])),
                )
              else
                ..._filteredContacts.map((c) {
                  final name = c['nickname'] ?? c['username'] ?? '';
                  final position = c['position'] ?? '';
                  final dept = c['department_name'] ?? '';
                  final isOnline = c['online_status'] == 'online';
                  return Container(
                    color: AppColors.cardBg,
                    child: ListTile(
                      leading: Stack(children: [
                        CircleAvatar(radius: 20, backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16))),
                        Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? AppColors.online : AppColors.offline, border: Border.all(color: AppColors.cardBg, width: 1.5)))),
                      ]),
                      title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      subtitle: Text('${dept.isNotEmpty ? "$dept | " : ""}$position', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      trailing: IconButton(icon: const Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.primary), onPressed: () => _startChat(c)),
                      onTap: () => _showContactDetail(c),
                    ),
                  );
                }),
            ]),
          ),
    );
  }

  Widget _buildQuickEntry(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
      onTap: onTap,
    );
  }
}

// ==================== 添加好友弹窗 ====================
class _AddContactDialog extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddContactDialog({required this.onAdded});
  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _searching = false;
  String? _error;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    setState(() { _searching = true; _error = null; _hasSearched = true; });
    final res = await ApiService.searchUsers(keyword);
    if (!mounted) return;
    if (res.isSuccess) {
      final data = res.data;
      List results = [];
      if (data is List) {
        results = data;
      } else if (data is Map) {
        results = data['list'] ?? data['users'] ?? [];
      }
      setState(() { _searchResults = results; _searching = false; });
    } else {
      setState(() { _error = res.message; _searching = false; });
    }
  }

  Future<void> _addContact(dynamic user) async {
    final res = await ApiService.addContact(user['id'].toString());
    if (!mounted) return;
    if (res.isSuccess) {
      widget.onAdded();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败: ${res.message}'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 420, height: 520,
        child: Column(children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(children: [
              const Icon(Icons.person_add, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('添加好友', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(),
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入用户名、手机号或姓名搜索',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _searching ? null : _search,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _searching
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('搜索'),
              ),
            ]),
          ),
          // 搜索结果
          Expanded(
            child: _searching
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 40, color: AppColors.error),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                  ]))
                : !_hasSearched
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.person_search, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('输入关键词搜索企业内的同事', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('支持用户名、手机号、姓名搜索', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ]))
                  : _searchResults.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('未找到匹配的用户', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        const Text('请尝试其他关键词', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ]))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) {
                          final user = _searchResults[i];
                          final name = user['nickname'] ?? user['username'] ?? '';
                          final dept = user['department_name'] ?? '';
                          final isContact = user['is_contact'] == true || user['is_contact'] == 1;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.15),
                              child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(dept.isNotEmpty ? dept : (user['phone'] ?? ''), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            trailing: isContact
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                                  child: const Text('已添加', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                )
                              : ElevatedButton(
                                  onPressed: () => _addContact(user),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text('添加', style: TextStyle(fontSize: 12)),
                                ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
