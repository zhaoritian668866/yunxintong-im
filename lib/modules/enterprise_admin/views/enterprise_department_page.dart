import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/mock_data.dart';

class EnterpriseDepartmentPage extends StatelessWidget {
  const EnterpriseDepartmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final departments = MockData.departments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 操作栏
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddDepartmentDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增部门'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 部门列表
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
                children: departments.map((d) => _DepartmentCard(
                  name: d.name,
                  managerName: d.managerName ?? '未指定',
                  memberCount: d.memberCount,
                  color: [AppColors.primary, AppColors.success, AppColors.warning, AppColors.info, AppColors.error][departments.indexOf(d) % 5],
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddDepartmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增部门'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(decoration: InputDecoration(labelText: '部门名称', hintText: '请输入部门名称')),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: '部门负责人', hintText: '请输入负责人姓名')),
              SizedBox(height: 12),
              TextField(decoration: InputDecoration(labelText: '上级部门', hintText: '可选，留空为顶级部门')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('确认添加')),
        ],
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  final String name;
  final String managerName;
  final int memberCount;
  final Color color;

  const _DepartmentCard({
    required this.name,
    required this.managerName,
    required this.memberCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_tree, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('负责人: $managerName', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('编辑')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.people, size: 16, color: color),
              const SizedBox(width: 6),
              Text('$memberCount 名成员', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('查看成员', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
