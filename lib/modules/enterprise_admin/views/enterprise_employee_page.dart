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
        if (empRes.isSuccess) {
          final eData = empRes.data;
          if (eData is Map) {
            _employees = List<Map<String, dynamic>>.from(eData['list'] ?? eData['employees'] ?? []);
          } else if (eData is List) {
            _employees = List<Map<String, dynamic>>.from(eData);
          }
        }
        if (deptRes.isSuccess) {
          final dData = deptRes.data;
          if (dData is List) {
            _departments = List<Map<String, dynamic>>.from(dData);
          } else if (dData is Map) {
            _departments = List<Map<String, dynamic>>.from(dData['departments'] ?? dData['list'] ?? []);
          }
        }
      });
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    var list = _employees;
    if (_searchQuery.isNotEmpty) {
      list = list.where((e) =>
        (e['nickname'] ?? e['name'] ?? '').toString().contains(_searchQuery) ||
        (e['username'] ?? '').toString().contains(_searchQuery) ||
        (e['phone'] ?? '').toString().contains(_searchQuery)
      ).toList();
    }
    if (_departmentFilter != '全部部门') {
      list = list.where((e) => (e['department_name'] ?? '') == _departmentFilter).toList();
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
        // 工具栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 280, child: TextField(
              decoration: InputDecoration(
                hintText: '搜索姓名、用户名或手机号...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.background,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.background,
              ),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _departmentFilter,
                items: ['全部部门', ..._departments.map((d) => d['name'] as String? ?? '')]
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _departmentFilter = v ?? '全部部门'),
              )),
            ),
            ElevatedButton.icon(
              onPressed: _showAddEmployeeDialog,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('添加员工'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // 员工表格
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                columns: const [
                  DataColumn(label: Text('员工', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('用户名', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('手机号', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('邮箱', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('部门', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('职位', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: employees.map((e) {
                  final status = e['status'] ?? 'active';
                  final isActive = status == 'active';
                  return DataRow(cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          (e['nickname'] ?? e['username'] ?? '?').toString().isNotEmpty
                              ? (e['nickname'] ?? e['username'] ?? '?').toString()[0]
                              : '?',
                          style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(e['nickname'] ?? e['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ])),
                    DataCell(Text(e['username'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                    DataCell(Text(e['phone'] ?? '-')),
                    DataCell(Text(e['email'] ?? '-', style: const TextStyle(fontSize: 13))),
                    DataCell(Text(e['department_name'] ?? '-')),
                    DataCell(Text(e['position'] ?? '-')),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? '正常' : '禁用',
                        style: TextStyle(fontSize: 12, color: isActive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    )),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                        onPressed: () => _showEditEmployeeDialog(e),
                        tooltip: '编辑',
                      ),
                      IconButton(
                        icon: Icon(
                          isActive ? Icons.block : Icons.check_circle_outline,
                          size: 18,
                          color: isActive ? AppColors.warning : AppColors.success,
                        ),
                        onPressed: () => _toggleEmployeeStatus(e),
                        tooltip: isActive ? '禁用' : '启用',
                      ),
                      IconButton(
                        icon: const Icon(Icons.lock_reset, size: 18, color: AppColors.info),
                        onPressed: () => _showResetPasswordDialog(e),
                        tooltip: '重置密码',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        onPressed: () => _deleteEmployee(e),
                        tooltip: '删除',
                      ),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Text('共 ${employees.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showAddEmployeeDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: '123456');
    final nicknameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    String? selectedDeptId;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.person_add, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('添加员工'),
        ]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: '用户名 *',
                hintText: '用于登录的账号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_circle_outlined, size: 20),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(
                labelText: '初始密码 *',
                hintText: '默认123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline, size: 20),
              ),
            )),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: nicknameCtrl,
            decoration: const InputDecoration(
              labelText: '姓名/昵称 *',
              hintText: '员工真实姓名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: '手机号',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
              keyboardType: TextInputType.phone,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              keyboardType: TextInputType.emailAddress,
            )),
          ]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: selectedDeptId,
              isExpanded: true,
              hint: const Row(children: [
                Icon(Icons.business_outlined, size: 20, color: Colors.grey),
                SizedBox(width: 12),
                Text('选择部门'),
              ]),
              items: _departments.map((d) => DropdownMenuItem(
                value: d['id']?.toString(),
                child: Text(d['name'] ?? ''),
              )).toList(),
              onChanged: (v) => setDialogState(() => selectedDeptId = v),
            )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: posCtrl,
            decoration: const InputDecoration(
              labelText: '职位',
              hintText: '如：前端工程师',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.work_outline, size: 20),
            ),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton.icon(
            onPressed: () async {
              if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('用户名和密码不能为空'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              if (nicknameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('姓名不能为空'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              Navigator.pop(ctx);
              final res = await ApiService.enterpriseAddEmployee({
                'username': usernameCtrl.text,
                'password': passwordCtrl.text,
                'nickname': nicknameCtrl.text,
                'phone': phoneCtrl.text,
                'email': emailCtrl.text,
                'department_id': selectedDeptId,
                'position': posCtrl.text,
              });
              if (res.isSuccess) {
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('员工 ${nicknameCtrl.text} 添加成功'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('添加失败: ${res.message}'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('确认添加'),
          ),
        ],
      ),
    ));
  }

  void _showEditEmployeeDialog(Map<String, dynamic> e) {
    final nicknameCtrl = TextEditingController(text: e['nickname'] ?? e['username'] ?? '');
    final phoneCtrl = TextEditingController(text: e['phone'] ?? '');
    final emailCtrl = TextEditingController(text: e['email'] ?? '');
    final posCtrl = TextEditingController(text: e['position'] ?? '');
    String? selectedDeptId = e['department_id']?.toString();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text('编辑员工 - ${e['nickname'] ?? e['username'] ?? ''}'),
        ]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          TextField(
            controller: nicknameCtrl,
            decoration: const InputDecoration(labelText: '姓名/昵称', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge_outlined, size: 20)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined, size: 20)),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: '邮箱', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined, size: 20)),
            )),
          ]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: selectedDeptId,
              isExpanded: true,
              hint: const Text('选择部门'),
              items: _departments.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text(d['name'] ?? ''))).toList(),
              onChanged: (v) => setDialogState(() => selectedDeptId = v),
            )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: posCtrl,
            decoration: const InputDecoration(labelText: '职位', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work_outline, size: 20)),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.enterpriseUpdateEmployee(e['id'], {
              'nickname': nicknameCtrl.text,
              'phone': phoneCtrl.text,
              'email': emailCtrl.text,
              'department_id': selectedDeptId,
              'position': posCtrl.text,
            });
            if (res.isSuccess) {
              _loadData();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('员工信息已更新'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error));
            }
          }, child: const Text('保存')),
        ],
      ),
    ));
  }

  void _toggleEmployeeStatus(Map<String, dynamic> e) {
    final isActive = (e['status'] ?? 'active') == 'active';
    final newStatus = isActive ? 'disabled' : 'active';
    final action = isActive ? '禁用' : '启用';

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('$action员工'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text('确定要$action ${e['nickname'] ?? e['username']} 吗？${isActive ? '禁用后该员工将无法登录系统。' : ''}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.enterpriseUpdateEmployee(e['id'], {'status': newStatus});
            if (res.isSuccess) {
              _loadData();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已${action}员工 ${e['nickname'] ?? e['username']}'), behavior: SnackBarBehavior.floating));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: isActive ? AppColors.warning : AppColors.success),
          child: Text(action),
        ),
      ],
    ));
  }

  void _showResetPasswordDialog(Map<String, dynamic> e) {
    final passwordCtrl = TextEditingController(text: '123456');

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.lock_reset, color: AppColors.info),
        const SizedBox(width: 8),
        Text('重置密码 - ${e['nickname'] ?? e['username']}'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('重置后员工需使用新密码登录', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        TextField(
          controller: passwordCtrl,
          decoration: const InputDecoration(
            labelText: '新密码',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline, size: 20),
          ),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          // 调用后端重置密码API
          final res = await ApiService.enterpriseResetPassword(e['id'], passwordCtrl.text);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(res.isSuccess ? '密码已重置为: ${passwordCtrl.text}' : '重置失败'),
              behavior: SnackBarBehavior.floating,
            ));
          }
        }, child: const Text('确认重置')),
      ],
    ));
  }

  void _deleteEmployee(Map<String, dynamic> e) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.error),
        SizedBox(width: 8),
        Text('删除员工'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('确定要删除 ${e['nickname'] ?? e['username']} 吗？'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(child: Text('此操作不可恢复，该员工的所有聊天记录也将被删除。', style: TextStyle(fontSize: 13, color: AppColors.error))),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.enterpriseDeleteEmployee(e['id']);
            if (res.isSuccess) {
              _loadData();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('员工已删除'), behavior: SnackBarBehavior.floating));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('确认删除'),
        ),
      ],
    ));
  }
}
