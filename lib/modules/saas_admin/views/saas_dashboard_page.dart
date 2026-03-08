import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../widgets/stat_card.dart';
import '../../../services/api_service.dart';

class SaasDashboardPage extends StatefulWidget {
  const SaasDashboardPage({super.key});

  @override
  State<SaasDashboardPage> createState() => _SaasDashboardPageState();
}

class _SaasDashboardPageState extends State<SaasDashboardPage> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _tenants = [];
  List<Map<String, dynamic>> _servers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final statsRes = await ApiService.saasGetStats();
    final tenantsRes = await ApiService.saasGetTenants();
    final serversRes = await ApiService.saasGetServers();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (statsRes.isSuccess) _stats = statsRes.data;
        if (tenantsRes.isSuccess) _tenants = List<Map<String, dynamic>>.from(tenantsRes.data?['tenants'] ?? []);
        if (serversRes.isSuccess) _servers = List<Map<String, dynamic>>.from(serversRes.data?['servers'] ?? []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.count(
              crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.8,
              children: [
                StatCard(title: '租户总数', value: '${_stats?['total_tenants'] ?? 0}', icon: Icons.business, color: AppColors.primary),
                StatCard(title: '活跃租户', value: '${_stats?['active_tenants'] ?? 0}', icon: Icons.check_circle_outline, color: AppColors.success),
                StatCard(title: '服务器总数', value: '${_stats?['total_servers'] ?? 0}', icon: Icons.dns, color: AppColors.warning, subtitle: '在线 ${_stats?['online_servers'] ?? 0} 台'),
                StatCard(title: '待处理工单', value: '${_stats?['pending_tickets'] ?? 0}', icon: Icons.support_agent, color: AppColors.info),
              ],
            );
          }),
          const SizedBox(height: 24),
          // 最近租户
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('最近租户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('查看全部')),
              ]),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.background),
                  columns: const [
                    DataColumn(label: Text('企业ID', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('企业名称', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('联系人', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('服务器IP', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                  rows: _tenants.take(5).map((t) => DataRow(cells: [
                    DataCell(Text(t['enterprise_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(t['name'] ?? '')),
                    DataCell(Text(t['contact_person'] ?? '')),
                    DataCell(Text(t['server_ip'] ?? '')),
                    DataCell(_buildStatusChip(t['status'] ?? '')),
                  ])).toList(),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          // 服务器状态
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('服务器资源概览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
                  children: _servers.map((s) => _buildServerCard(s)).toList(),
                );
              }),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color; String text;
    switch (status) {
      case 'running': color = AppColors.success; text = '运行中';
      case 'stopped': color = AppColors.error; text = '已停止';
      case 'deploying': color = AppColors.warning; text = '部署中';
      default: color = AppColors.error; text = '异常';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildServerCard(Map<String, dynamic> server) {
    final isOnline = server['status'] == 'online';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: isOnline ? AppColors.success : AppColors.offline, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(server['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          Text(server['ip'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildUsageBar('CPU', (server['cpu_usage'] ?? 0).toDouble())),
          const SizedBox(width: 8),
          Expanded(child: _buildUsageBar('内存', (server['memory_usage'] ?? 0).toDouble())),
          const SizedBox(width: 8),
          Expanded(child: _buildUsageBar('磁盘', (server['disk_usage'] ?? 0).toDouble())),
        ]),
      ]),
    );
  }

  Widget _buildUsageBar(String label, double value) {
    final color = value > 80 ? AppColors.error : (value > 60 ? AppColors.warning : AppColors.success);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label ${value.toInt()}%', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      const SizedBox(height: 3),
      ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: value / 100, backgroundColor: AppColors.border, valueColor: AlwaysStoppedAnimation(color), minHeight: 4)),
    ]);
  }
}
