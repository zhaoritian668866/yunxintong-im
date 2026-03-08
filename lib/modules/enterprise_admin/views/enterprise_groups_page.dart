import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class EnterpriseGroupsPage extends StatefulWidget {
  const EnterpriseGroupsPage({super.key});

  @override
  State<EnterpriseGroupsPage> createState() => _EnterpriseGroupsPageState();
}

class _EnterpriseGroupsPageState extends State<EnterpriseGroupsPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final res = await ApiService.adminGetGroups(keyword: _searchQuery.isNotEmpty ? _searchQuery : null);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess) {
          final d = res.data;
          if (d is Map) {
            _groups = List<Map<String, dynamic>>.from(d['list'] ?? d['groups'] ?? []);
          } else if (d is List) {
            _groups = List<Map<String, dynamic>>.from(d);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 工具栏
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 280, child: TextField(
            decoration: InputDecoration(
              hintText: '搜索群组名称...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              _searchQuery = v;
              _loadGroups();
            },
          )),
          ElevatedButton.icon(
            onPressed: _showCreateGroupDialog,
            icon: const Icon(Icons.group_add, size: 18),
            label: const Text('创建群组'),
          ),
          OutlinedButton.icon(
            onPressed: _loadGroups,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新'),
          ),
        ]),
        const SizedBox(height: 20),
        // 统计
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 800 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildStatCard('群组总数', '${_groups.length}', Icons.group, AppColors.primary),
              _buildStatCard('活跃群组', '${_groups.where((g) => g['status'] != 'disbanded').length}', Icons.forum, AppColors.success),
              _buildStatCard('总成员数', '${_groups.fold<int>(0, (sum, g) => sum + ((g['member_count'] ?? 0) as int))}', Icons.people, AppColors.info),
              _buildStatCard('今日消息', '${_groups.fold<int>(0, (sum, g) => sum + ((g['today_messages'] ?? 0) as int))}', Icons.message, AppColors.warning),
            ],
          );
        }),
        const SizedBox(height: 20),
        // 群组列表
        _isLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
            : _groups.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('暂无群组', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('点击"创建群组"开始', style: TextStyle(color: Colors.grey.shade400)),
                    ]),
                  ))
                : LayoutBuilder(builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.6,
                      children: _groups.map((g) => _buildGroupCard(g)).toList(),
                    );
                  }),
      ]),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
      ]),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final type = group['type'] ?? 'group';
    final isNotice = type == 'notice';
    final memberCount = group['member_count'] ?? 0;
    final maxMembers = group['max_members'] ?? 500;
    final isDisbanded = group['status'] == 'disbanded';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDisbanded ? Colors.grey.shade50 : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDisbanded ? Colors.grey.shade300 : AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (isNotice ? AppColors.warning : AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isNotice ? Icons.campaign : Icons.group, color: isNotice ? AppColors.warning : AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (isNotice ? AppColors.warning : AppColors.info).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(isNotice ? '通知群' : '普通群', style: TextStyle(fontSize: 10, color: isNotice ? AppColors.warning : AppColors.info)),
              ),
              if (isDisbanded) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('已解散', style: TextStyle(fontSize: 10, color: AppColors.error)),
                ),
              ],
            ]),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
            onSelected: (v) {
              switch (v) {
                case 'edit': _showEditGroupDialog(group);
                case 'members': _showMembersDialog(group);
                case 'disband': _disbandGroup(group);
                case 'delete': _deleteGroup(group);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('编辑')])),
              const PopupMenuItem(value: 'members', child: Row(children: [Icon(Icons.people, size: 16, color: AppColors.info), SizedBox(width: 8), Text('成员管理')])),
              if (!isDisbanded)
                const PopupMenuItem(value: 'disband', child: Row(children: [Icon(Icons.block, size: 16, color: AppColors.warning), SizedBox(width: 8), Text('解散群组')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ]),
        const Spacer(),
        if (group['description'] != null && group['description'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(group['description'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        Row(children: [
          Icon(Icons.person, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text('群主: ${group['owner_name'] ?? '未知'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          Text('$memberCount/$maxMembers 人', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: maxMembers > 0 ? memberCount / maxMembers : 0,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(memberCount / maxMembers > 0.8 ? AppColors.warning : AppColors.primary),
            minHeight: 4,
          ),
        ),
      ]),
    );
  }

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final maxMembersCtrl = TextEditingController(text: '500');
    String groupType = 'group';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Row(children: [Icon(Icons.group_add, color: AppColors.primary), SizedBox(width: 8), Text('创建群组')]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: '群组名称 *', prefixIcon: const Icon(Icons.group), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: groupType,
          decoration: InputDecoration(labelText: '群组类型', prefixIcon: const Icon(Icons.category), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          items: const [
            DropdownMenuItem(value: 'group', child: Text('普通群组')),
            DropdownMenuItem(value: 'notice', child: Text('通知群组 (仅管理员可发言)')),
          ],
          onChanged: (v) => setDialogState(() => groupType = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descCtrl,
          maxLines: 3,
          decoration: InputDecoration(labelText: '群组描述', prefixIcon: const Icon(Icons.description), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: maxMembersCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: '最大成员数', prefixIcon: const Icon(Icons.people), suffixText: '人', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          final res = await ApiService.adminCreateGroup({
            'name': nameCtrl.text,
            'type': groupType,
            'description': descCtrl.text,
            'max_members': int.tryParse(maxMembersCtrl.text) ?? 500,
          });
          if (res.isSuccess) {
            _loadGroups();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('群组创建成功'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message.isNotEmpty ? res.message : '创建失败'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
          }
        }, child: const Text('创建')),
      ],
    )));
  }

  void _showEditGroupDialog(Map<String, dynamic> group) {
    final nameCtrl = TextEditingController(text: group['name']);
    final descCtrl = TextEditingController(text: group['description'] ?? '');
    final maxMembersCtrl = TextEditingController(text: '${group['max_members'] ?? 500}');

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.edit, color: AppColors.primary), SizedBox(width: 8), Text('编辑群组')]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: '群组名称', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 12),
        TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: '群组描述', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 12),
        TextField(controller: maxMembersCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '最大成员数', suffixText: '人', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          await ApiService.adminUpdateGroup(group['id'], {
            'name': nameCtrl.text,
            'description': descCtrl.text,
            'max_members': int.tryParse(maxMembersCtrl.text) ?? 500,
          });
          _loadGroups();
        }, child: const Text('保存')),
      ],
    ));
  }

  void _showMembersDialog(Map<String, dynamic> group) {
    showDialog(context: context, builder: (ctx) => _GroupMembersDialog(group: group));
  }

  void _disbandGroup(Map<String, dynamic> group) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.warning, color: AppColors.warning), SizedBox(width: 8), Text('解散群组')]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text('确定要解散群组「${group['name']}」吗？解散后群成员将无法继续在此群中发送消息。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
          onPressed: () async {
            Navigator.pop(ctx);
            await ApiService.adminUpdateGroup(group['id'], {'status': 'disbanded'});
            _loadGroups();
          },
          child: const Text('确认解散'),
        ),
      ],
    ));
  }

  void _deleteGroup(Map<String, dynamic> group) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.delete_forever, color: AppColors.error), SizedBox(width: 8), Text('删除群组')]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text('确定要永久删除群组「${group['name']}」吗？此操作不可恢复，所有聊天记录将被清除。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () async {
            Navigator.pop(ctx);
            await ApiService.adminDeleteGroup(group['id']);
            _loadGroups();
          },
          child: const Text('永久删除'),
        ),
      ],
    ));
  }
}

// 群成员管理弹窗
class _GroupMembersDialog extends StatefulWidget {
  final Map<String, dynamic> group;
  const _GroupMembersDialog({required this.group});

  @override
  State<_GroupMembersDialog> createState() => _GroupMembersDialogState();
}

class _GroupMembersDialogState extends State<_GroupMembersDialog> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final res = await ApiService.adminGetGroupMembers(widget.group['id']);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess) {
          final d = res.data;
          if (d is List) {
            _members = List<Map<String, dynamic>>.from(d);
          } else if (d is Map) {
            _members = List<Map<String, dynamic>>.from(d['list'] ?? d['members'] ?? []);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.people, color: AppColors.info),
        const SizedBox(width: 8),
        Text('${widget.group['name']} - 成员管理'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Row(children: [
                  Text('共 ${_members.length} 名成员', style: const TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('添加成员'),
                  ),
                ]),
                const Divider(),
                Expanded(
                  child: _members.isEmpty
                      ? const Center(child: Text('暂无成员', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final m = _members[index];
                            final role = m['role'] ?? 'member';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: role == 'owner' ? AppColors.warning : (role == 'admin' ? AppColors.primary : AppColors.info),
                                child: Text((m['nickname'] ?? m['username'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                              title: Text(m['nickname'] ?? m['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(role == 'owner' ? '群主' : (role == 'admin' ? '管理员' : '成员'), style: TextStyle(fontSize: 12, color: role == 'owner' ? AppColors.warning : AppColors.textSecondary)),
                              trailing: role != 'owner'
                                  ? IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.error),
                                      onPressed: () async {
                                        await ApiService.adminRemoveGroupMember(widget.group['id'], m['user_id'] ?? m['id']);
                                        _loadMembers();
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }

  void _showAddMemberDialog() {
    final userIdCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('添加成员'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(
        controller: userIdCtrl,
        decoration: InputDecoration(labelText: '用户名或ID', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (userIdCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          await ApiService.adminAddGroupMember(widget.group['id'], userIdCtrl.text);
          _loadMembers();
        }, child: const Text('添加')),
      ],
    ));
  }
}
