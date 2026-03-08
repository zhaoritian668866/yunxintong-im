import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../widgets/stat_card.dart';
import '../../../services/mock_data.dart';

class EnterpriseDashboardPage extends StatelessWidget {
  const EnterpriseDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final employees = MockData.employees;
    final departments = MockData.departments;
    final onlineCount = employees.where((e) => e.isOnline).length;

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
                  StatCard(title: '员工总数', value: '256', icon: Icons.people, color: AppColors.primary, trend: '+2%', trendUp: true),
                  StatCard(title: '在线用户', value: '$onlineCount', icon: Icons.circle, color: AppColors.success, subtitle: '占比 ${(onlineCount * 100 / employees.length).toInt()}%'),
                  StatCard(title: '今日消息', value: '12,458', icon: Icons.chat, color: AppColors.warning, trend: '+15%', trendUp: true),
                  StatCard(title: '活跃群组', value: '32', icon: Icons.group, color: AppColors.info),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // 部门活跃度
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
                const Text('部门活跃度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ...departments.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text(d.name, style: const TextStyle(fontSize: 13))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: d.memberCount / 50,
                            minHeight: 20,
                            backgroundColor: AppColors.border.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation(AppColors.primary.withValues(alpha: 0.7 + (d.memberCount / 200))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(width: 40, child: Text('${d.memberCount}人', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 最近活跃员工
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
                    const Text('最近活跃员工', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                      DataColumn(label: Text('姓名', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('工号', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('部门', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('职位', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('设备数', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                    rows: employees.map((e) => DataRow(cells: [
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(e.name[0], style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                          ),
                          const SizedBox(width: 8),
                          Text(e.name),
                        ],
                      )),
                      DataCell(Text(e.employeeNo)),
                      DataCell(Text(e.department)),
                      DataCell(Text(e.position)),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (e.isOnline ? AppColors.success : AppColors.offline).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(e.isOnline ? '在线' : '离线', style: TextStyle(fontSize: 12, color: e.isOnline ? AppColors.success : AppColors.offline)),
                      )),
                      DataCell(Text('${e.deviceCount}')),
                    ])).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
