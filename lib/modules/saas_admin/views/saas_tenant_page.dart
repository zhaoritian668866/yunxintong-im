import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../services/mock_data.dart';

class SaasTenantPage extends StatefulWidget {
  const SaasTenantPage({super.key});

  @override
  State<SaasTenantPage> createState() => _SaasTenantPageState();
}

class _SaasTenantPageState extends State<SaasTenantPage> {
  String _searchQuery = '';
  String _statusFilter = '全部';

  @override
  Widget build(BuildContext context) {
    var tenants = MockData.tenants;
    if (_searchQuery.isNotEmpty) {
      tenants = tenants.where((t) => t.name.contains(_searchQuery) || t.enterpriseId.contains(_searchQuery)).toList();
    }
    if (_statusFilter != '全部') {
      tenants = tenants.where((t) {
        switch (_statusFilter) {
          case '运行中': return t.status == TenantStatus.running;
          case '已停止': return t.status == TenantStatus.stopped;
          default: return true;
        }
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 操作栏
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索租户名称或企业ID...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              _buildFilterChip('全部'),
              _buildFilterChip('运行中'),
              _buildFilterChip('已停止'),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddTenantDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增租户'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 租户列表
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                columns: const [
                  DataColumn(label: Text('企业ID', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('企业名称', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('联系人', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('联系电话', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('服务器IP', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('到期时间', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: tenants.map((t) => DataRow(cells: [
                  DataCell(Text(t.enterpriseId, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.primary))),
                  DataCell(Text(t.name)),
                  DataCell(Text(t.contactPerson)),
                  DataCell(Text(t.contactPhone)),
                  DataCell(Text(t.serverIp, style: const TextStyle(fontFamily: 'monospace'))),
                  DataCell(_buildStatusChip(t.status)),
                  DataCell(Text('${t.expiresAt.year}-${t.expiresAt.month.toString().padLeft(2, '0')}-${t.expiresAt.day.toString().padLeft(2, '0')}')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary), onPressed: () {}, tooltip: '编辑'),
                      IconButton(icon: const Icon(Icons.settings_outlined, size: 18, color: AppColors.textSecondary), onPressed: () {}, tooltip: '配置'),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () {}, tooltip: '删除'),
                    ],
                  )),
                ])).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 分页
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('共 ${tenants.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () {}),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
                    child: const Text('2', style: TextStyle(fontSize: 13)),
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () {}),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = label),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontSize: 13),
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
    );
  }

  Widget _buildStatusChip(TenantStatus status) {
    Color color;
    String text;
    switch (status) {
      case TenantStatus.running: color = AppColors.success; text = '运行中';
      case TenantStatus.stopped: color = AppColors.error; text = '已停止';
      case TenantStatus.deploying: color = AppColors.warning; text = '部署中';
      case TenantStatus.error: color = AppColors.error; text = '异常';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _showAddTenantDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增租户'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextField(decoration: InputDecoration(labelText: '企业名称', hintText: '请输入企业名称')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '联系人', hintText: '请输入联系人姓名')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '联系电话', hintText: '请输入联系电话')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '服务器IP', hintText: '请输入分配的服务器IP')),
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
