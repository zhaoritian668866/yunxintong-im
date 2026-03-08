import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class EnterpriseEmployeePage extends StatefulWidget {
  const EnterpriseEmployeePage({super.key});

  @override
  State<EnterpriseEmployeePage> createState() => _EnterpriseEmployeePageState();
}

class _EnterpriseEmployeePageState extends State<EnterpriseEmployeePage> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _departmentFilter = '全部部门';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final empRes = await ApiService.enterpriseGetEmployees();
    final deptRes = await ApiService.enterpriseGetDepartments();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (empRes.isSuccess) _employees = List<Map<String, dynamic>>.from(empRes.data?['employees'] ?? []);
        if (deptRes.isSuccess) _departments = List<Map<String, dynamic>>.from(deptRes.data?['departments'] ?? []);
      });
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    var list = _employees;
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) => (e['name'] ?? '').toString().contains(_searchQuery) || (e['employee_no'] ?? '').toString().contains(_searchQuery)).toList();
    }
    if (_departmentFilter != '全部部门') {
      list = list.where((e) => e['department'] == _departmentFilter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final employees = _filteredEmployees;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 260, child: TextField(
            decoration: InputDecoration(hintText: '搜索员工姓名或工号...', prefixIcon: const Icon(Icons.search, size: 20), contentPadding: const EdgeInsets.symmetric(vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onChanged: (v) => setState(() => _searchQuery = v),
          )),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _departmentFilter,
              items: ['全部部门', ..._departments.map((d) => d['name'] as String? ?? '')].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _departmentFilter = v ?? '全部部门'),
            ))),
          ElevatedButton.icon(onPressed: _showAddEmployeeDialog, icon: const Icon(Icons.person_add, size: 18), label: const Text('添加员工')),
        ]),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
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
            rows: employees.map((e) {
              final isOnline = e['is_online'] == 1;
              return DataRow(cells: [
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 16, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text((e['name'] ?? '?')[0], style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 10), Text(e['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                ])),
                DataCell(Text(e['employee_no'] ?? '', style: const TextStyle(fontFamily: 'monospace'))),
                DataCell(Text(e['department'] ?? '')),
                DataCell(Text(e['position'] ?? '')),
                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (isOnline ? AppColors.success : AppColors.offline).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(isOnline ? '在线' : '离线', style: TextStyle(fontSize: 12, color: isOnline ? AppColors.success : AppColors.offline, fontWeight: FontWeight.w600)),
                )),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${e['device_count'] ?? 1}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  InkWell(onTap: () => _showDeviceDialog(e), child: const Icon(Icons.edit, size: 14, color: AppColors.primary)),
                ])),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary), onPressed: () => _showEditEmployeeDialog(e), tooltip: '编辑'),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => _deleteEmployee(e), tooltip: '删除'),
                ])),
              ]);
            }).toList(),
          )),
        ),
        const SizedBox(height: 16),
        Text('共 ${employees.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }

  void _showAddEmployeeDialog() {
    final nameCtrl = TextEditingController();
    final noCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    String dept = _departments.isNotEmpty ? (_departments.first['name'] ?? '') : '';

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('添加员工'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名 *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: noCtrl, decoration: const InputDecoration(labelText: '工号', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: dept.isNotEmpty ? dept : null, isExpanded: true, hint: const Text('选择部门'),
            items: _departments.map((d) => DropdownMenuItem(value: d['name'] as String?, child: Text(d['name'] ?? ''))).toList(),
            onChanged: (v) => dept = v ?? '',
          ))),
        const SizedBox(height: 12),
        TextField(controller: posCtrl, decoration: const InputDecoration(labelText: '职位', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          final res = await ApiService.enterpriseAddEmployee({
            'name': nameCtrl.text, 'employee_no': noCtrl.text, 'phone': phoneCtrl.text, 'department': dept, 'position': posCtrl.text,
          });
          if (res.isSuccess) { _loadData(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('员工添加成功'))); }
        }, child: const Text('确认添加')),
      ],
    ));
  }

  void _showEditEmployeeDialog(Map<String, dynamic> e) {
    final nameCtrl = TextEditingController(text: e['name']);
    final posCtrl = TextEditingController(text: e['position']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('编辑员工'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: posCtrl, decoration: const InputDecoration(labelText: '职位', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async { Navigator.pop(ctx); await ApiService.enterpriseUpdateEmployee(e['id'], {'name': nameCtrl.text, 'position': posCtrl.text}); _loadData(); }, child: const Text('保存')),
      ],
    ));
  }

  void _deleteEmployee(Map<String, dynamic> e) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('删除员工'), content: Text('确定要删除 ${e['name']} 吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () async { Navigator.pop(ctx); await ApiService.enterpriseDeleteEmployee(e['id']); _loadData(); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showDeviceDialog(Map<String, dynamic> e) {
    final ctrl = TextEditingController(text: '${e['device_count'] ?? 1}');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('设备数管理 - ${e['name']}'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('当前设备连接数: ${e['device_count'] ?? 1}', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 16),
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: '新设备数上限', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async { Navigator.pop(ctx); await ApiService.enterpriseUpdateEmployee(e['id'], {'device_count': int.tryParse(ctrl.text) ?? 1}); _loadData(); }, child: const Text('确认修改')),
      ],
    ));
  }
}
