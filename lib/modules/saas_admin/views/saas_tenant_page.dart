import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class SaasTenantPage extends StatefulWidget {
  const SaasTenantPage({super.key});

  @override
  State<SaasTenantPage> createState() => _SaasTenantPageState();
}

class _SaasTenantPageState extends State<SaasTenantPage> {
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = '全部';

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    final res = await ApiService.saasGetTenants();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess) {
          final tData = res.data;
          if (tData is Map) {
            _tenants = List<Map<String, dynamic>>.from(tData['list'] ?? tData['tenants'] ?? []);
          } else if (tData is List) {
            _tenants = List<Map<String, dynamic>>.from(tData);
          }
        }
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTenants {
    var list = _tenants;
    if (_searchQuery.isNotEmpty) {
      list = list.where((t) => (t['name'] ?? '').toString().contains(_searchQuery) || (t['enterprise_id'] ?? '').toString().contains(_searchQuery)).toList();
    }
    if (_statusFilter != '全部') {
      list = list.where((t) {
        switch (_statusFilter) {
          case '运行中': return t['status'] == 'running';
          case '已停止': return t['status'] == 'stopped';
          default: return true;
        }
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final tenants = _filteredTenants;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 280, child: TextField(
            decoration: InputDecoration(hintText: '搜索租户名称或企业ID...', prefixIcon: const Icon(Icons.search, size: 20), contentPadding: const EdgeInsets.symmetric(vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onChanged: (v) => setState(() => _searchQuery = v),
          )),
          _buildFilterChip('全部'), _buildFilterChip('运行中'), _buildFilterChip('已停止'),
          const SizedBox(width: 8),
          ElevatedButton.icon(onPressed: _showAddTenantDialog, icon: const Icon(Icons.add, size: 18), label: const Text('新增租户')),
        ]),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
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
                DataColumn(label: Text('API端口', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: tenants.map((t) => DataRow(cells: [
                DataCell(Text(t['enterprise_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.primary))),
                DataCell(Text(t['name'] ?? '')),
                DataCell(Text(t['contact_person'] ?? '')),
                DataCell(Text(t['contact_phone'] ?? '')),
                DataCell(Text(t['server_ip'] ?? '', style: const TextStyle(fontFamily: 'monospace'))),
                DataCell(Text('${t['api_port'] ?? ''}', style: const TextStyle(fontFamily: 'monospace'))),
                DataCell(_buildStatusChip(t['status'] ?? '')),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary), onPressed: () => _showEditTenantDialog(t), tooltip: '编辑'),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => _deleteTenant(t), tooltip: '删除'),
                ])),
              ])).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('共 ${tenants.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return ChoiceChip(label: Text(label), selected: isSelected, onSelected: (_) => setState(() => _statusFilter = label),
      selectedColor: AppColors.primary.withValues(alpha: 0.15), labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontSize: 13),
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border));
  }

  Widget _buildStatusChip(String status) {
    Color color; String text;
    switch (status) {
      case 'running': color = AppColors.success; text = '运行中';
      case 'stopped': color = AppColors.error; text = '已停止';
      case 'deploying': color = AppColors.warning; text = '部署中';
      default: color = AppColors.error; text = '异常';
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)));
  }

  void _showAddTenantDialog() {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '4001');
    final sshUserCtrl = TextEditingController(text: 'root');
    final sshPortCtrl = TextEditingController(text: '22');
    final sshPassCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新增租户'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '企业名称 *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: '联系人', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: '服务器IP *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: portCtrl, decoration: const InputDecoration(labelText: 'API端口', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: sshPortCtrl, decoration: const InputDecoration(labelText: 'SSH端口', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: sshUserCtrl, decoration: const InputDecoration(labelText: 'SSH用户名', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: sshPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'SSH密码', border: OutlineInputBorder())),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (nameCtrl.text.isEmpty || ipCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          final res = await ApiService.saasCreateTenant({
            'name': nameCtrl.text, 'contact_person': contactCtrl.text, 'contact_phone': phoneCtrl.text,
            'server_ip': ipCtrl.text, 'api_port': int.tryParse(portCtrl.text) ?? 4001,
            'ssh_user': sshUserCtrl.text, 'ssh_port': int.tryParse(sshPortCtrl.text) ?? 22, 'ssh_password': sshPassCtrl.text,
          });
          if (res.isSuccess) { _loadTenants(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('租户创建成功'))); }
          else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message.isNotEmpty ? res.message : '创建失败'))); }
        }, child: const Text('确认添加')),
      ],
    ));
  }

  void _showEditTenantDialog(Map<String, dynamic> t) {
    final nameCtrl = TextEditingController(text: t['name']);
    final contactCtrl = TextEditingController(text: t['contact_person']);
    final phoneCtrl = TextEditingController(text: t['contact_phone']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('编辑租户'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '企业名称', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: '联系人', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          await ApiService.saasUpdateTenant(t['id'], {'name': nameCtrl.text, 'contact_person': contactCtrl.text, 'contact_phone': phoneCtrl.text});
          _loadTenants();
        }, child: const Text('保存')),
      ],
    ));
  }

  void _deleteTenant(Map<String, dynamic> t) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('删除租户'), content: Text('确定要删除 ${t['name']} 吗？此操作不可恢复。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () async { Navigator.pop(ctx); await ApiService.saasDeleteTenant(t['id']); _loadTenants(); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}
