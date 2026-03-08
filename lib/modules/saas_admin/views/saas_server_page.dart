import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/models.dart';
import '../../../services/mock_data.dart';

class SaasServerPage extends StatelessWidget {
  const SaasServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final servers = MockData.servers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 操作栏
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddServerDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增服务器'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新状态'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 服务器卡片网格
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: servers.map((s) => _ServerCard(server: s)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddServerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增服务器'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TextField(decoration: InputDecoration(labelText: '服务器名称', hintText: '例如: 服务器-07')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: 'IP地址', hintText: '例如: 192.168.1.100')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: 'SSH端口', hintText: '默认: 22')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: 'SSH用户名', hintText: '例如: root')),
              const SizedBox(height: 12),
              const TextField(decoration: InputDecoration(labelText: 'SSH密码/密钥', hintText: '请输入SSH密码或私钥路径'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('服务器连接测试中...'), behavior: SnackBarBehavior.floating));
            },
            icon: const Icon(Icons.link, size: 16),
            label: const Text('测试连接并添加'),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final ServerInfo server;
  const _ServerCard({required this.server});

  @override
  Widget build(BuildContext context) {
    final isOnline = server.status == ServerStatus.online;
    final statusColor = isOnline ? AppColors.success : AppColors.offline;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.dns, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(server.ip, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(isOnline ? '在线' : '离线', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 资源使用率
          _buildUsageRow('CPU', server.cpuUsage),
          const SizedBox(height: 8),
          _buildUsageRow('内存', server.memoryUsage),
          const SizedBox(height: 8),
          _buildUsageRow('磁盘', server.diskUsage),
          const Spacer(),
          // 底部信息
          Row(
            children: [
              Icon(Icons.business, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  server.tenantName ?? '未分配',
                  style: TextStyle(fontSize: 12, color: server.tenantName != null ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'terminal', child: Row(children: [Icon(Icons.terminal, size: 16), SizedBox(width: 8), Text('终端')])),
                  const PopupMenuItem(value: 'restart', child: Row(children: [Icon(Icons.restart_alt, size: 16), SizedBox(width: 8), Text('重启')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: AppColors.error), SizedBox(width: 8), Text('删除', style: TextStyle(color: AppColors.error))])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageRow(String label, double value) {
    final color = value > 80 ? AppColors.error : (value > 60 ? AppColors.warning : AppColors.success);
    return Row(
      children: [
        SizedBox(width: 32, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 36, child: Text('${value.toInt()}%', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
      ],
    );
  }
}
