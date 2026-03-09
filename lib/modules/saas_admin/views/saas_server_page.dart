import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class SaasServerPage extends StatefulWidget {
  const SaasServerPage({super.key});

  @override
  State<SaasServerPage> createState() => _SaasServerPageState();
}

class _SaasServerPageState extends State<SaasServerPage> {
  List<Map<String, dynamic>> _servers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    final res = await ApiService.saasGetServers();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess) {
          final sData = res.data;
          if (sData is List) {
            _servers = List<Map<String, dynamic>>.from(sData);
          } else if (sData is Map) {
            _servers = List<Map<String, dynamic>>.from(sData['servers'] ?? sData['list'] ?? []);
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
        // 工具栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            ElevatedButton.icon(
              onPressed: _showAddServerDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增服务器'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _loadServers,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新状态'),
            ),
            const Spacer(),
            Text('共 ${_servers.length} 台服务器', style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(height: 20),
        _servers.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.all(64),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.dns_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('暂无服务器', style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('点击上方"新增服务器"添加服务器资源', style: TextStyle(color: Colors.grey.shade400)),
                ]),
              ))
            : LayoutBuilder(builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: _servers.map((s) => _buildServerCard(s)).toList(),
                );
              }),
      ]),
    );
  }

  Widget _buildServerCard(Map<String, dynamic> server) {
    final isOnline = server['status'] == 'online';
    final statusColor = isOnline ? AppColors.success : AppColors.offline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.dns, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(server['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(server['ip_address'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace')),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(isOnline ? '在线' : '离线', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        // 硬件信息
        Row(children: [
          _buildInfoChip(Icons.memory, '${server['cpu_cores'] ?? 0} 核'),
          const SizedBox(width: 8),
          _buildInfoChip(Icons.storage, '${server['memory_gb'] ?? 0} GB'),
          const SizedBox(width: 8),
          _buildInfoChip(Icons.disc_full, '${server['disk_gb'] ?? 0} GB'),
        ]),
        const SizedBox(height: 12),
        _buildUsageRow('CPU', (server['cpu_usage'] ?? 0).toDouble()),
        const SizedBox(height: 6),
        _buildUsageRow('内存', (server['memory_usage'] ?? 0).toDouble()),
        const SizedBox(height: 6),
        _buildUsageRow('磁盘', (server['disk_usage'] ?? 0).toDouble()),
        const Spacer(),
        const Divider(height: 16),
        Row(children: [
          Icon(Icons.business, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Expanded(child: Text(
            server['tenant_name'] ?? '未分配租户',
            style: TextStyle(fontSize: 12, color: server['tenant_name'] != null ? AppColors.primary : AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          )),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
            onSelected: (v) {
              switch (v) {
                case 'test': _testServerConnection(server);
                case 'edit': _showEditServerDialog(server);
                case 'delete': _deleteServer(server);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'test', child: Row(children: [Icon(Icons.wifi_tethering, size: 16, color: AppColors.success), SizedBox(width: 8), Text('测试连接')])),
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('编辑')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildUsageRow(String label, double value) {
    final color = value > 80 ? AppColors.error : (value > 60 ? AppColors.warning : AppColors.success);
    return Row(children: [
      SizedBox(width: 32, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(value: value / 100, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(color), minHeight: 6),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 36, child: Text('${value.toInt()}%', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
    ]);
  }

  void _showAddServerDialog() {
    final nameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final sshPortCtrl = TextEditingController(text: '22');
    final sshUserCtrl = TextEditingController(text: 'root');
    final sshPassCtrl = TextEditingController();
    final cpuCtrl = TextEditingController(text: '4');
    final memCtrl = TextEditingController(text: '8');
    final diskCtrl = TextEditingController(text: '100');

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.dns, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        const Text('新增服务器'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '服务器名称 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.label_outline, size: 20)))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP地址 *', hintText: '如: 192.168.1.100', border: OutlineInputBorder(), prefixIcon: Icon(Icons.language, size: 20)))),
        ]),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: Text('SSH连接信息', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: sshUserCtrl, decoration: const InputDecoration(labelText: 'SSH用户名', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: sshPortCtrl, decoration: const InputDecoration(labelText: 'SSH端口', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: sshPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'SSH密码', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline, size: 20))),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: Text('硬件配置', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: cpuCtrl, decoration: const InputDecoration(labelText: 'CPU核数', border: OutlineInputBorder(), suffixText: '核'), keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: memCtrl, decoration: const InputDecoration(labelText: '内存', border: OutlineInputBorder(), suffixText: 'GB'), keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: diskCtrl, decoration: const InputDecoration(labelText: '磁盘', border: OutlineInputBorder(), suffixText: 'GB'), keyboardType: TextInputType.number)),
        ]),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton.icon(
          onPressed: () async {
            if (nameCtrl.text.isEmpty || ipCtrl.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('服务器名称和IP地址不能为空'), behavior: SnackBarBehavior.floating));
              return;
            }
            Navigator.pop(ctx);
            final res = await ApiService.saasAddServer({
              'name': nameCtrl.text,
              'ip_address': ipCtrl.text,
              'ssh_port': int.tryParse(sshPortCtrl.text) ?? 22,
              'ssh_user': sshUserCtrl.text,
              'ssh_password': sshPassCtrl.text,
              'cpu_cores': int.tryParse(cpuCtrl.text) ?? 0,
              'memory_gb': int.tryParse(memCtrl.text) ?? 0,
              'disk_gb': int.tryParse(diskCtrl.text) ?? 0,
            });
            if (res.isSuccess) {
              _loadServers();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('服务器 ${nameCtrl.text} 添加成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: ${res.message}'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.error));
            }
          },
          icon: const Icon(Icons.link, size: 16),
          label: const Text('添加'),
        ),
      ],
    ));
  }

  void _showEditServerDialog(Map<String, dynamic> server) {
    final nameCtrl = TextEditingController(text: server['name']);
    final ipCtrl = TextEditingController(text: server['ip_address']);
    final cpuCtrl = TextEditingController(text: '${server['cpu_cores'] ?? 0}');
    final memCtrl = TextEditingController(text: '${server['memory_gb'] ?? 0}');
    final diskCtrl = TextEditingController(text: '${server['disk_gb'] ?? 0}');

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.edit, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text('编辑服务器 - ${server['name']}'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '服务器名称', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP地址', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: cpuCtrl, decoration: const InputDecoration(labelText: 'CPU核数', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: memCtrl, decoration: const InputDecoration(labelText: '内存(GB)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: diskCtrl, decoration: const InputDecoration(labelText: '磁盘(GB)', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
        ]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          await ApiService.saasUpdateServer(server['id'], {
            'name': nameCtrl.text,
            'ip_address': ipCtrl.text,
            'cpu_cores': int.tryParse(cpuCtrl.text) ?? 0,
            'memory_gb': int.tryParse(memCtrl.text) ?? 0,
            'disk_gb': int.tryParse(diskCtrl.text) ?? 0,
          });
          _loadServers();
        }, child: const Text('保存')),
      ],
    ));
  }

  void _testServerConnection(Map<String, dynamic> server) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 12),
        Text('正在测试连接 ${server['name']}...'),
      ]),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 30),
    ));

    final res = await ApiService.saasTestServer(server['id'].toString());
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (res.isSuccess) {
      _loadServers();
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: 8),
          Text('SSH连接成功'),
        ]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Container(
          width: 450,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
          child: Text(res.data?['output']?.toString() ?? 'OK', style: const TextStyle(color: Color(0xFF4EC9B0), fontSize: 12, fontFamily: 'monospace')),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ));
    } else {
      _loadServers();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('SSH连接失败: ${res.message}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _deleteServer(Map<String, dynamic> s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.error),
        SizedBox(width: 8),
        Text('删除服务器'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text('确定要删除服务器 ${s['name']}（${s['ip_address']}）吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ApiService.saasDeleteServer(s['id']);
            _loadServers();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('服务器已删除'), behavior: SnackBarBehavior.floating));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('确认删除'),
        ),
      ],
    ));
  }
}
