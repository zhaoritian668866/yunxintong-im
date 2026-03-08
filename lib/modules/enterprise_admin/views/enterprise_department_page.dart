import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class EnterpriseDepartmentPage extends StatefulWidget {
  const EnterpriseDepartmentPage({super.key});

  @override
  State<EnterpriseDepartmentPage> createState() => _EnterpriseDepartmentPageState();
}

class _EnterpriseDepartmentPageState extends State<EnterpriseDepartmentPage> {
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final res = await ApiService.enterpriseGetDepartments();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess) {
          final dData = res.data;
          if (dData is List) {
            _departments = List<Map<String, dynamic>>.from(dData);
          } else if (dData is Map) {
            _departments = List<Map<String, dynamic>>.from(dData['departments'] ?? dData['list'] ?? []);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ElevatedButton.icon(onPressed: _showAddDepartmentDialog, icon: const Icon(Icons.add, size: 18), label: const Text('新增部门')),
          const SizedBox(width: 12),
          OutlinedButton.icon(onPressed: _loadDepartments, icon: const Icon(Icons.refresh, size: 18), label: const Text('刷新')),
        ]),
        const SizedBox(height: 20),
        _departments.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(48), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('暂无部门', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ])))
            : LayoutBuilder(builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.6,
                  children: _departments.asMap().entries.map((entry) {
                    final d = entry.value;
                    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.info, AppColors.error];
                    final color = colors[entry.key % colors.length];
                    return _buildDepartmentCard(d, color);
                  }).toList(),
                );
              }),
      ]),
    );
  }

  Widget _buildDepartmentCard(Map<String, dynamic> dept, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.account_tree, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dept['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('负责人: ${dept['leader'] ?? '未指定'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
            onSelected: (v) { if (v == 'edit') _showEditDepartmentDialog(dept); if (v == 'delete') _deleteDepartment(dept); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('编辑')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ]),
        const Spacer(),
        Row(children: [
          Icon(Icons.people, size: 16, color: color),
          const SizedBox(width: 6),
          Text('${dept['employee_count'] ?? dept['member_count'] ?? 0} 名成员', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  void _showAddDepartmentDialog() {
    final nameCtrl = TextEditingController();
    final leaderCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新增部门'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '部门名称 *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: leaderCtrl, decoration: const InputDecoration(labelText: '部门负责人', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder()), maxLines: 2),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          final res = await ApiService.enterpriseAddDepartment({'name': nameCtrl.text, 'leader': leaderCtrl.text, 'description': descCtrl.text});
          if (res.isSuccess) { _loadDepartments(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('部门创建成功'))); }
        }, child: const Text('确认添加')),
      ],
    ));
  }

  void _showEditDepartmentDialog(Map<String, dynamic> dept) {
    final nameCtrl = TextEditingController(text: dept['name']);
    final leaderCtrl = TextEditingController(text: dept['leader']);
    final descCtrl = TextEditingController(text: dept['description']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('编辑部门'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '部门名称', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: leaderCtrl, decoration: const InputDecoration(labelText: '部门负责人', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述', border: OutlineInputBorder()), maxLines: 2),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async { Navigator.pop(ctx); await ApiService.enterpriseUpdateDepartment(dept['id'], {'name': nameCtrl.text, 'leader': leaderCtrl.text, 'description': descCtrl.text}); _loadDepartments(); }, child: const Text('保存')),
      ],
    ));
  }

  void _deleteDepartment(Map<String, dynamic> dept) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('删除部门'), content: Text('确定要删除 ${dept['name']} 吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () async { Navigator.pop(ctx); await ApiService.enterpriseDeleteDepartment(dept['id']); _loadDepartments(); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}
