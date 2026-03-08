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
    setState(() => _isLoading = true);
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
        // 顶部操作栏
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_tree, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('部门管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('共 ${_departments.length} 个部门', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ])),
            ElevatedButton.icon(
              onPressed: _showAddDepartmentDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增部门'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _loadDepartments,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // 部门卡片网格
        _departments.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(60), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.business_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('暂无部门', style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
                const SizedBox(height: 8),
                Text('点击上方"新增部门"按钮创建第一个部门', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              ])))
            : LayoutBuilder(builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.8,
                  children: _departments.asMap().entries.map((entry) {
                    final d = entry.value;
                    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.info, const Color(0xFF9C27B0)];
                    final color = colors[entry.key % colors.length];
                    return _buildDepartmentCard(d, color);
                  }).toList(),
                );
              }),
      ]),
    );
  }

  Widget _buildDepartmentCard(Map<String, dynamic> dept, Color color) {
    final employeeCount = dept['employee_count'] ?? dept['member_count'] ?? 0;
    final description = dept['description'] ?? '';
    final sortOrder = dept['sort_order'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.account_tree, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dept['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (description.isNotEmpty)
              Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'edit') _showEditDepartmentDialog(dept);
              if (v == 'delete') _deleteDepartment(dept);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('编辑')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.people, size: 16, color: color),
            const SizedBox(width: 6),
            Text('$employeeCount 名成员', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            const Spacer(),
            if (sortOrder > 0) ...[
              Icon(Icons.sort, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text('排序: $sortOrder', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ]),
        ),
      ]),
    );
  }

  void _showAddDepartmentDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final sortCtrl = TextEditingController(text: '0');
    String? selectedParentId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_business, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('新增部门'),
        ]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: '部门名称 *',
              hintText: '如：技术部、市场部',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: '部门描述',
              hintText: '简要描述部门职责',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description_outlined, size: 20),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          if (_departments.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: selectedParentId,
                isExpanded: true,
                hint: const Row(children: [
                  Icon(Icons.subdirectory_arrow_right, size: 20, color: Colors.grey),
                  SizedBox(width: 12),
                  Text('上级部门（可选）'),
                ]),
                items: [
                  const DropdownMenuItem(value: null, child: Text('无（顶级部门）')),
                  ..._departments.map((d) => DropdownMenuItem(
                    value: d['id']?.toString(),
                    child: Text(d['name'] ?? ''),
                  )),
                ],
                onChanged: (v) => setDialogState(() => selectedParentId = v),
              )),
            ),
          if (_departments.isNotEmpty) const SizedBox(height: 16),
          TextField(
            controller: sortCtrl,
            decoration: const InputDecoration(
              labelText: '排序序号',
              hintText: '数字越小越靠前',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.sort, size: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton.icon(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('部门名称不能为空'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              Navigator.pop(ctx);
              final res = await ApiService.enterpriseAddDepartment({
                'name': nameCtrl.text,
                'description': descCtrl.text,
                'parent_id': selectedParentId,
                'sort_order': int.tryParse(sortCtrl.text) ?? 0,
              });
              if (res.isSuccess) {
                _loadDepartments();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('部门 ${nameCtrl.text} 创建成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('创建失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('确认创建'),
          ),
        ],
      ),
    ));
  }

  void _showEditDepartmentDialog(Map<String, dynamic> dept) {
    final nameCtrl = TextEditingController(text: dept['name']);
    final descCtrl = TextEditingController(text: dept['description'] ?? '');
    final sortCtrl = TextEditingController(text: (dept['sort_order'] ?? 0).toString());

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.edit, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text('编辑部门 - ${dept['name']}'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: '部门名称', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business, size: 20)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: descCtrl,
          decoration: const InputDecoration(labelText: '部门描述', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined, size: 20)),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: sortCtrl,
          decoration: const InputDecoration(labelText: '排序序号', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sort, size: 20)),
          keyboardType: TextInputType.number,
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.enterpriseUpdateDepartment(dept['id'], {
              'name': nameCtrl.text,
              'description': descCtrl.text,
              'sort_order': int.tryParse(sortCtrl.text) ?? 0,
            });
            if (res.isSuccess) {
              _loadDepartments();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('部门信息已更新'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error));
            }
          },
          icon: const Icon(Icons.check, size: 18),
          label: const Text('保存'),
        ),
      ],
    ));
  }

  void _deleteDepartment(Map<String, dynamic> dept) {
    final employeeCount = dept['employee_count'] ?? 0;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.error),
        SizedBox(width: 8),
        Text('删除部门'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('确定要删除 ${dept['name']} 吗？'),
        if (employeeCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(child: Text('该部门下有 $employeeCount 名员工，删除后这些员工将变为无部门状态。', style: const TextStyle(fontSize: 13, color: AppColors.warning))),
            ]),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.enterpriseDeleteDepartment(dept['id']);
            if (res.isSuccess) {
              _loadDepartments();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${dept['name']} 已删除'), behavior: SnackBarBehavior.floating));
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('确认删除'),
        ),
      ],
    ));
  }
}
