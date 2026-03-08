import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class WorkbenchPage extends StatelessWidget {
  const WorkbenchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('工作台')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 常用应用
          _buildSection('常用应用', [
            _AppItem(icon: Icons.event_note, label: '日程', color: AppColors.primary),
            _AppItem(icon: Icons.task_alt, label: '任务', color: AppColors.success),
            _AppItem(icon: Icons.cloud_upload, label: '云盘', color: AppColors.warning),
            _AppItem(icon: Icons.how_to_vote, label: '审批', color: AppColors.info),
          ]),
          const SizedBox(height: 16),
          // 办公工具
          _buildSection('办公工具', [
            _AppItem(icon: Icons.access_time, label: '考勤', color: AppColors.primary),
            _AppItem(icon: Icons.meeting_room, label: '会议室', color: AppColors.success),
            _AppItem(icon: Icons.announcement, label: '公告', color: AppColors.error),
            _AppItem(icon: Icons.poll, label: '投票', color: AppColors.warning),
            _AppItem(icon: Icons.receipt_long, label: '报销', color: AppColors.info),
            _AppItem(icon: Icons.calendar_month, label: '日历', color: AppColors.primary),
          ]),
          const SizedBox(height: 16),
          // 数据统计
          _buildSection('数据统计', [
            _AppItem(icon: Icons.bar_chart, label: '报表', color: AppColors.primary),
            _AppItem(icon: Icons.pie_chart, label: '分析', color: AppColors.success),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_AppItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Wrap(
              spacing: 0,
              runSpacing: 8,
              children: items.map((item) => SizedBox(
                width: 80,
                child: Column(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(item.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppItem {
  final IconData icon;
  final String label;
  final Color color;
  const _AppItem({required this.icon, required this.label, required this.color});
}
