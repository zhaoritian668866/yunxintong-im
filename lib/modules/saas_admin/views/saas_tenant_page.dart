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
    setState(() => _isLoading = true);
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
      list = list.where((t) =>
        (t['name'] ?? '').toString().contains(_searchQuery) ||
        (t['enterprise_id'] ?? '').toString().contains(_searchQuery) ||
        (t['contact_person'] ?? '').toString().contains(_searchQuery)
      ).toList();
    }
    if (_statusFilter != '全部') {
      list = list.where((t) {
        switch (_statusFilter) {
          case '运行中': return t['status'] == 'running';
          case '已停止': return t['status'] == 'stopped';
          case '待部署': return t['status'] == 'pending';
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
        // 工具栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 300, child: TextField(
              decoration: InputDecoration(
                hintText: '搜索租户名称、企业ID或联系人...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.background,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            )),
            _buildFilterChip('全部'),
            _buildFilterChip('运行中'),
            _buildFilterChip('已停止'),
            _buildFilterChip('待部署'),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showAddTenantDialog,
              icon: const Icon(Icons.add_business, size: 18),
              label: const Text('新增租户'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            ),
            OutlinedButton.icon(
              onPressed: _loadTenants,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // 租户表格
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
                  DataColumn(label: Text('企业ID', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('企业名称', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('联系人', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('联系电话', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('套餐', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('最大用户数', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('API地址', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('创建时间', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: tenants.map((t) => DataRow(cells: [
                  DataCell(Text(t['enterprise_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.primary, fontFamily: 'monospace'))),
                  DataCell(Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(t['contact_person'] ?? '-')),
                  DataCell(Text(t['contact_phone'] ?? '-')),
                  DataCell(_buildPlanChip(t['plan'] ?? 'basic')),
                  DataCell(Text('${t['max_users'] ?? 100}', style: const TextStyle(fontFamily: 'monospace'))),
                  DataCell(Text(t['api_url'] ?? '-', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                  DataCell(_buildStatusChip(t['status'] ?? 'pending')),
                  DataCell(Text(_formatDate(t['created_at'] ?? ''), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.info), onPressed: () => _showTenantDetail(t), tooltip: '详情'),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary), onPressed: () => _showEditTenantDialog(t), tooltip: '编辑'),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => _deleteTenant(t), tooltip: '删除'),
                  ])),
                ])).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('共 ${tenants.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ]),
        ),
      ]),
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

  Widget _buildStatusChip(String status) {
    Color color; String text;
    switch (status) {
      case 'running': color = AppColors.success; text = '运行中';
      case 'stopped': color = AppColors.error; text = '已停止';
      case 'deploying': color = AppColors.warning; text = '部署中';
      case 'pending': color = Colors.grey; text = '待部署';
      default: color = AppColors.error; text = '异常';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPlanChip(String plan) {
    Color color; String text;
    switch (plan) {
      case 'enterprise': color = Colors.purple; text = '企业版';
      case 'professional': color = AppColors.primary; text = '专业版';
      case 'basic': color = Colors.grey; text = '基础版';
      default: color = Colors.grey; text = plan;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  void _showAddTenantDialog() {
    final entIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String plan = 'basic';
    final maxUsersCtrl = TextEditingController(text: '100');

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_business, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('新增租户'),
        ]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: entIdCtrl,
              decoration: const InputDecoration(
                labelText: '企业ID *',
                hintText: '如: ENT002',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag, size: 20),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '企业名称 *',
                hintText: '如: 某某科技有限公司',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business, size: 20),
              ),
            )),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: contactCtrl,
              decoration: const InputDecoration(labelText: '联系人', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline, size: 20)),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined, size: 20)),
            )),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: '联系邮箱', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined, size: 20)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: plan,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'basic', child: Text('基础版')),
                  DropdownMenuItem(value: 'professional', child: Text('专业版')),
                  DropdownMenuItem(value: 'enterprise', child: Text('企业版')),
                ],
                onChanged: (v) => setDialogState(() => plan = v ?? 'basic'),
              )),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: maxUsersCtrl,
              decoration: const InputDecoration(labelText: '最大用户数', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people_outline, size: 20)),
              keyboardType: TextInputType.number,
            )),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.info),
              SizedBox(width: 8),
              Expanded(child: Text('创建租户后，请在"服务器管理"中添加服务器，然后在"一键部署"中为该租户部署服务。', style: TextStyle(fontSize: 12, color: AppColors.info))),
            ]),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton.icon(
            onPressed: () async {
              if (entIdCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('企业ID和企业名称不能为空'), behavior: SnackBarBehavior.floating));
                return;
              }
              Navigator.pop(ctx);
              final res = await ApiService.saasCreateTenant({
                'enterprise_id': entIdCtrl.text,
                'name': nameCtrl.text,
                'contact_person': contactCtrl.text,
                'contact_phone': phoneCtrl.text,
                'contact_email': emailCtrl.text,
                'plan': plan,
                'max_users': int.tryParse(maxUsersCtrl.text) ?? 100,
              });
              if (res.isSuccess) {
                _loadTenants();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('租户 ${nameCtrl.text} 创建成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error));
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('确认创建'),
          ),
        ],
      ),
    ));
  }

  void _showEditTenantDialog(Map<String, dynamic> t) {
    final nameCtrl = TextEditingController(text: t['name']);
    final contactCtrl = TextEditingController(text: t['contact_person']);
    final phoneCtrl = TextEditingController(text: t['contact_phone']);
    final emailCtrl = TextEditingController(text: t['contact_email']);
    String plan = t['plan'] ?? 'basic';
    final maxUsersCtrl = TextEditingController(text: '${t['max_users'] ?? 100}');
    String status = t['status'] ?? 'pending';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text('编辑租户 - ${t['enterprise_id']}'),
        ]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '企业名称', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: '联系人', border: OutlineInputBorder()))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '联系电话', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: '联系邮箱', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: plan, isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'basic', child: Text('基础版')),
                  DropdownMenuItem(value: 'professional', child: Text('专业版')),
                  DropdownMenuItem(value: 'enterprise', child: Text('企业版')),
                ],
                onChanged: (v) => setDialogState(() => plan = v ?? 'basic'),
              )),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: maxUsersCtrl, decoration: const InputDecoration(labelText: '最大用户数', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: status, isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('待部署')),
                DropdownMenuItem(value: 'running', child: Text('运行中')),
                DropdownMenuItem(value: 'stopped', child: Text('已停止')),
              ],
              onChanged: (v) => setDialogState(() => status = v ?? 'pending'),
            )),
          ),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.saasUpdateTenant(t['id'], {
              'name': nameCtrl.text,
              'contact_person': contactCtrl.text,
              'contact_phone': phoneCtrl.text,
              'contact_email': emailCtrl.text,
              'plan': plan,
              'max_users': int.tryParse(maxUsersCtrl.text) ?? 100,
              'status': status,
            });
            if (res.isSuccess) {
              _loadTenants();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('租户信息已更新'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            }
          }, child: const Text('保存')),
        ],
      ),
    ));
  }

  void _showTenantDetail(Map<String, dynamic> t) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.business, color: AppColors.info, size: 20),
        ),
        const SizedBox(width: 12),
        Text(t['name'] ?? ''),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _detailRow('企业ID', t['enterprise_id'] ?? '-'),
        _detailRow('企业名称', t['name'] ?? '-'),
        _detailRow('联系人', t['contact_person'] ?? '-'),
        _detailRow('联系电话', t['contact_phone'] ?? '-'),
        _detailRow('联系邮箱', t['contact_email'] ?? '-'),
        _detailRow('套餐', t['plan'] ?? 'basic'),
        _detailRow('最大用户数', '${t['max_users'] ?? 100}'),
        _detailRow('API地址', t['api_url'] ?? '未配置'),
        _detailRow('管理后台地址', t['admin_url'] ?? '未配置'),
        _detailRow('WebSocket地址', t['ws_url'] ?? '未配置'),
        _detailRow('状态', t['status'] ?? 'pending'),
        _detailRow('创建时间', _formatDate(t['created_at'] ?? '')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
      ],
    ));
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  void _deleteTenant(Map<String, dynamic> t) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.error),
        SizedBox(width: 8),
        Text('删除租户'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('确定要删除 ${t['name']}（${t['enterprise_id']}）吗？'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(child: Text('此操作不可恢复，该租户的所有数据将被永久删除。', style: TextStyle(fontSize: 13, color: AppColors.error))),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.saasDeleteTenant(t['id']);
            if (res.isSuccess) {
              _loadTenants();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('租户已删除'), behavior: SnackBarBehavior.floating));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('确认删除'),
        ),
      ],
    ));
  }
}
