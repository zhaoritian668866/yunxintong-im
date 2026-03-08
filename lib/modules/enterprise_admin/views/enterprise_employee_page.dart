import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../services/mock_data.dart';

class EnterpriseEmployeePage extends StatefulWidget {
  const EnterpriseEmployeePage({super.key});

  @override
  State<EnterpriseEmployeePage> createState() => _EnterpriseEmployeePageState();
}

class _EnterpriseEmployeePageState extends State<EnterpriseEmployeePage> {
  String _searchQuery = '';
  String _departmentFilter = '全部部门';

  @override
  Widget build(BuildContext context) {
    var employees = MockData.employees;
    if (_searchQuery.isNotEmpty) {
      employees = employees.where((e) => e.name.contains(_searchQuery) || e.employeeNo.contains(_searchQuery)).toList();
    }
    if (_departmentFilter != '全部部门') {
      employees = employees.where((e) => e.department == _departmentFilter).toList();
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
                width: 260,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索员工姓名或工号...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _departmentFilter,
                    items: ['全部部门', ...MockData.departments.map((d) => d.name)].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (v) => setState(() => _departmentFilter = v ?? '全部部门'),
                  ),
                ),
              ),
              ElevatedButton.icon(onPressed: () => _showAddEmployeeDialog(), icon: const Icon(Icons.person_add, size: 18), label: const Text('添加员工')),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file, size: 18), label: const Text('批量导入')),
            ],
          ),
          const SizedBox(height: 20),
          // 员工列表
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
                  DataColumn(label: Text('姓名', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('工号', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('部门', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('职位', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('设备数', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: employees.map((e) => DataRow(cells: [
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text(e.name[0], style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 10),
                    Text(e.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ])),
                  DataCell(Text(e.employeeNo, style: const TextStyle(fontFamily: 'monospace'))),
                  DataCell(Text(e.department)),
                  DataCell(Text(e.position)),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (e.isOnline ? AppColors.success : AppColors.offline).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(e.isOnline ? '在线' : '离线', style: TextStyle(fontSize: 12, color: e.isOnline ? AppColors.success : AppColors.offline, fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${e.deviceCount}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showDeviceDialog(e),
                      child: const Icon(Icons.edit, size: 14, color: AppColors.primary),
                    ),
                  ])),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary), onPressed: () {}, tooltip: '编辑'),
                    IconButton(icon: const Icon(Icons.block, size: 18, color: AppColors.warning), onPressed: () {}, tooltip: '禁用'),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () {}, tooltip: '删除'),
                  ])),
                ])).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('共 ${employees.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () {}),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)), child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 13))),
                  IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () {}),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加员工'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextField(decoration: InputDecoration(labelText: '姓名', hintText: '请输入员工姓名')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '工号', hintText: '请输入员工工号')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '手机号', hintText: '请输入手机号')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '部门', hintText: '请选择部门')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: '职位', hintText: '请输入职位')),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('默认设备数: ', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
                    child: const Text('1', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  const Text('(可在后台调整)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
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

  void _showDeviceDialog(Employee employee) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设备数管理 - ${employee.name}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前设备连接数: ${employee.deviceCount}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(labelText: '新设备数上限', hintText: '请输入数字'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            const Text('新注册用户默认1台设备，可在此调整上限', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('确认修改')),
        ],
      ),
    );
  }
}
