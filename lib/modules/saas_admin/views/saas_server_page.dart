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
        Row(children: [
          ElevatedButton.icon(onPressed: _showAddServerDialog, icon: const Icon(Icons.add, size: 18), label: const Text('新增服务器')),
          const SizedBox(width: 12),
          OutlinedButton.icon(onPressed: _loadServers, icon: const Icon(Icons.refresh, size: 18), label: const Text('刷新状态')),
        ]),
        const SizedBox(height: 20),
        _servers.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(48), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.dns_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('暂无服务器', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                const SizedBox(height: 8),
                Text('点击上方"新增服务器"添加', style: TextStyle(color: Colors.grey.shade400)),
              ])))
            : LayoutBuilder(builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3,
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
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.dns, color: statusColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(server['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(server['ip_address'] ?? server['ip'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace')),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(isOnline ? '在线' : '离线', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
            ])),
        ]),
        const SizedBox(height: 16),
        _buildUsageRow('CPU', (server['cpu_usage'] ?? 0).toDouble()),
        const SizedBox(height: 8),
        _buildUsageRow('内存', (server['memory_usage'] ?? 0).toDouble()),
        const SizedBox(height: 8),
        _buildUsageRow('磁盘', (server['disk_usage'] ?? 0).toDouble()),
        const Spacer(),
        Row(children: [
          Icon(Icons.business, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Expanded(child: Text(server['tenant_name'] ?? '未分配', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
            onSelected: (v) { if (v == 'delete') _deleteServer(server); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'restart', child: Row(children: [Icon(Icons.restart_alt, size: 16), SizedBox(width: 8), Text('重启')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _buildUsageRow(String label, double value) {
    final color = value > 80 ? AppColors.error : (value > 60 ? AppColors.warning : AppColors.success);
    return Row(children: [
      SizedBox(width: 32, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: value / 100, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(color), minHeight: 6))),
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

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新增服务器'), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '服务器名称 *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP地址 *', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: sshPortCtrl, decoration: const InputDecoration(labelText: 'SSH端口', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: sshUserCtrl, decoration: const InputDecoration(labelText: 'SSH用户名', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: sshPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'SSH密码', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton.icon(onPressed: () async {
          if (nameCtrl.text.isEmpty || ipCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          final res = await ApiService.saasAddServer({
            'name': nameCtrl.text, 'ip': ipCtrl.text,
            'ssh_port': int.tryParse(sshPortCtrl.text) ?? 22, 'ssh_user': sshUserCtrl.text, 'ssh_password': sshPassCtrl.text,
          });
          if (res.isSuccess) { _loadServers(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('服务器添加成功'))); }
        }, icon: const Icon(Icons.link, size: 16), label: const Text('添加')),
      ],
    ));
  }

  void _deleteServer(Map<String, dynamic> s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('删除服务器'), content: Text('确定要删除 ${s['name']} 吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () async { Navigator.pop(ctx); await ApiService.saasDeleteServer(s['id']); _loadServers(); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}
