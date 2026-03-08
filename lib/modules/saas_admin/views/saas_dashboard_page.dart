import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../widgets/stat_card.dart';
import '../../../models/models.dart';
import '../../../services/mock_data.dart';

class SaasDashboardPage extends StatelessWidget {
  const SaasDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tenants = MockData.tenants;
    final servers = MockData.servers;
    final runningTenants = tenants.where((t) => t.status == TenantStatus.running).length;
    final onlineServers = servers.where((s) => s.status == ServerStatus.online).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计卡片
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                children: [
                  StatCard(title: '租户总数', value: '${tenants.length}', icon: Icons.business, color: AppColors.primary, trend: '+12%', trendUp: true),
                  StatCard(title: '活跃租户', value: '$runningTenants', icon: Icons.check_circle_outline, color: AppColors.success, trend: '+5%', trendUp: true),
                  StatCard(title: '服务器总数', value: '${servers.length}', icon: Icons.dns, color: AppColors.warning, subtitle: '在线 $onlineServers 台'),
                  StatCard(title: '待处理工单', value: '3', icon: Icons.support_agent, color: AppColors.info),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // 最近租户
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('最近租户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(onPressed: () {}, child: const Text('查看全部')),
                  ],
                ),
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
                      DataColumn(label: Text('员工数', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                    rows: tenants.take(5).map((t) => DataRow(cells: [
                      DataCell(Text(t.enterpriseId, style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(t.name)),
                      DataCell(Text(t.contactPerson)),
                      DataCell(Text(t.serverIp)),
                      DataCell(_buildStatusChip(t.status)),
                      DataCell(Text('${t.employeeCount}')),
                    ])).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 服务器状态
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('服务器资源概览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: crossCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: servers.map((s) => _buildServerCard(s)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TenantStatus status) {
    Color color;
    String text;
    switch (status) {
      case TenantStatus.running:
        color = AppColors.success; text = '运行中';
      case TenantStatus.stopped:
        color = AppColors.error; text = '已停止';
      case TenantStatus.deploying:
        color = AppColors.warning; text = '部署中';
      case TenantStatus.error:
        color = AppColors.error; text = '异常';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildServerCard(ServerInfo server) {
    final statusColor = server.status == ServerStatus.online ? AppColors.success : AppColors.offline;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Text(server.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Text(server.ip, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildUsageBar('CPU', server.cpuUsage)),
              const SizedBox(width: 8),
              Expanded(child: _buildUsageBar('内存', server.memoryUsage)),
              const SizedBox(width: 8),
              Expanded(child: _buildUsageBar('磁盘', server.diskUsage)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBar(String label, double value) {
    final color = value > 80 ? AppColors.error : (value > 60 ? AppColors.warning : AppColors.success);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label ${value.toInt()}%', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
