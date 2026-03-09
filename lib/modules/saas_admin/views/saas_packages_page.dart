import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class SaasPackagesPage extends StatefulWidget {
  const SaasPackagesPage({super.key});
  @override
  State<SaasPackagesPage> createState() => _SaasPackagesPageState();
}

class _SaasPackagesPageState extends State<SaasPackagesPage> {
  List<Map<String, dynamic>> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() { _isLoading = true; });
    final res = await ApiService.saasGetPackages();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.isSuccess) {
        _packages = List<Map<String, dynamic>>.from(res.data is List ? res.data : []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 标题栏
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2, color: Colors.deepPurple, size: 24),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('部署包管理', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('管理不同版本的企业后端部署包，支持标准版和定制版', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadPackages,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('创建定制版'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // 部署包列表
            ..._packages.map((pkg) => _buildPackageCard(pkg)),

            if (_packages.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('暂无部署包', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ]),
              ),
          ]),
        );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final isDefault = pkg['is_default'] == 1;
    final tenantCount = pkg['tenant_count'] ?? 0;
    final dirExists = pkg['dir_exists'] == true;
    final status = pkg['status'] ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDefault ? Colors.deepPurple.withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isDefault ? Colors.deepPurple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDefault ? Icons.verified : Icons.extension,
              color: isDefault ? Colors.deepPurple : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(pkg['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDefault ? Colors.deepPurple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isDefault ? '默认' : '定制版',
                  style: TextStyle(fontSize: 11, color: isDefault ? Colors.deepPurple : Colors.blue, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('v${pkg['version'] ?? '1.0.0'}', style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w500)),
              ),
              if (!dirExists) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('目录缺失', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(pkg['description'] ?? '暂无描述', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ])),
          // 操作按钮
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('$tenantCount 个租户', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () => _showEditDialog(pkg),
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: '编辑',
              style: IconButton.styleFrom(foregroundColor: Colors.blue),
            ),
            if (!isDefault)
              IconButton(
                onPressed: () => _confirmDelete(pkg),
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: '删除',
                style: IconButton.styleFrom(foregroundColor: AppColors.error),
              ),
          ]),
        ]),
        const SizedBox(height: 12),
        // 详细信息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            _infoItem(Icons.folder_outlined, '目录', pkg['dir_name'] ?? ''),
            const SizedBox(width: 24),
            _infoItem(Icons.access_time, '创建时间', _formatDate(pkg['created_at'])),
            const SizedBox(width: 24),
            _infoItem(Icons.update, '更新时间', _formatDate(pkg['updated_at'])),
            if (pkg['base_package_id'] != null && pkg['base_package_id'].toString().isNotEmpty) ...[
              const SizedBox(width: 24),
              _infoItem(Icons.content_copy, '基于', _findPackageName(pkg['base_package_id'])),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text('$label: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }

  String _findPackageName(String? packageId) {
    if (packageId == null || packageId.isEmpty) return '-';
    final pkg = _packages.firstWhere((p) => p['id'] == packageId, orElse: () => {});
    return pkg.isNotEmpty ? (pkg['name'] ?? '-') : '-';
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      final dt = DateTime.parse(date);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return date;
    }
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final versionCtrl = TextEditingController(text: '1.0.0');
    final descCtrl = TextEditingController();
    String? selectedBaseId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.add_circle, color: Colors.deepPurple, size: 28),
            const SizedBox(width: 8),
            const Text('创建定制版部署包'),
          ]),
          content: SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: '部署包名称 *',
                  hintText: '例如：XX企业定制版',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: versionCtrl,
                decoration: InputDecoration(
                  labelText: '版本号',
                  hintText: '例如：1.0.0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '描述',
                  hintText: '描述此部署包的定制内容',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedBaseId,
                decoration: InputDecoration(
                  labelText: '基于哪个版本复制 *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.content_copy),
                ),
                items: _packages.map((p) => DropdownMenuItem(
                  value: p['id'].toString(),
                  child: Text('${p['name']} v${p['version']}'),
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedBaseId = v),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '创建定制版会复制基础版的全部代码文件（不含node_modules和数据），'
                    '您可以在服务器上修改定制版的代码，然后将定制版绑定给对应的租户。',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  )),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入部署包名称'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                if (selectedBaseId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请选择基础版本'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final res = await ApiService.saasCreatePackage({
                  'name': nameCtrl.text,
                  'version': versionCtrl.text,
                  'description': descCtrl.text,
                  'base_package_id': selectedBaseId,
                });
                if (res.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('定制版 "${nameCtrl.text}" 创建成功'),
                      ]),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  _loadPackages();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('创建失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('创建'),
            ),
          ],
        );
      }),
    );
  }

  void _showEditDialog(Map<String, dynamic> pkg) {
    final nameCtrl = TextEditingController(text: pkg['name'] ?? '');
    final versionCtrl = TextEditingController(text: pkg['version'] ?? '1.0.0');
    final descCtrl = TextEditingController(text: pkg['description'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.edit, color: Colors.blue, size: 28),
          const SizedBox(width: 8),
          const Text('编辑部署包'),
        ]),
        content: SizedBox(
          width: 500,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: '部署包名称',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: versionCtrl,
              decoration: InputDecoration(
                labelText: '版本号',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '描述',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.description),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.saasUpdatePackage(pkg['id'].toString(), {
                'name': nameCtrl.text,
                'version': versionCtrl.text,
                'description': descCtrl.text,
              });
              if (res.isSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('更新成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                );
                _loadPackages();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('更新失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> pkg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
          const SizedBox(width: 8),
          const Text('确认删除'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('确定要删除部署包 "${pkg['name']}" 吗？'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('此操作将删除部署包目录及所有代码文件，且不可恢复。如有租户正在使用此部署包，需先切换其部署包版本。',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.saasDeletePackage(pkg['id'].toString());
              if (res.isSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('删除成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                );
                _loadPackages();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }
}
