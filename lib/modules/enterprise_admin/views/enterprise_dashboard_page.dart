import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../widgets/stat_card.dart';
import '../../../services/api_service.dart';

class EnterpriseDashboardPage extends StatefulWidget {
  const EnterpriseDashboardPage({super.key});

  @override
  State<EnterpriseDashboardPage> createState() => _EnterpriseDashboardPageState();
}

class _EnterpriseDashboardPageState extends State<EnterpriseDashboardPage> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final statsRes = await ApiService.enterpriseGetStats();
    final deptRes = await ApiService.enterpriseGetDepartments();
    final empRes = await ApiService.enterpriseGetEmployees();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (statsRes.isSuccess) _stats = statsRes.data;
        if (deptRes.isSuccess) _departments = List<Map<String, dynamic>>.from(deptRes.data?['departments'] ?? []);
        if (empRes.isSuccess) _employees = List<Map<String, dynamic>>.from(empRes.data?['employees'] ?? []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
          return GridView.count(
            crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.8,
            children: [
              StatCard(title: '员工总数', value: '${_stats?['total_employees'] ?? 0}', icon: Icons.people, color: AppColors.primary),
              StatCard(title: '在线用户', value: '${_stats?['online_users'] ?? 0}', icon: Icons.circle, color: AppColors.success),
              StatCard(title: '今日消息', value: '${_stats?['today_messages'] ?? 0}', icon: Icons.chat, color: AppColors.warning),
              StatCard(title: '活跃群组', value: '${_stats?['active_groups'] ?? 0}', icon: Icons.group, color: AppColors.info),
            ],
          );
        }),
        const SizedBox(height: 24),
        // 部门活跃度
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('部门活跃度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (_departments.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('暂无部门数据', style: TextStyle(color: AppColors.textSecondary)))
            else
              ..._departments.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  SizedBox(width: 80, child: Text(d['name'] ?? '', style: const TextStyle(fontSize: 13))),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                    value: ((d['member_count'] ?? 0) as num).toDouble() / 50, minHeight: 20,
                    backgroundColor: AppColors.border.withValues(alpha: 0.3), valueColor: AlwaysStoppedAnimation(AppColors.primary.withValues(alpha: 0.8)),
                  ))),
                  const SizedBox(width: 12),
                  SizedBox(width: 40, child: Text('${d['member_count'] ?? 0}人', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                ]),
              )),
          ]),
        ),
        const SizedBox(height: 24),
        // 最近活跃员工
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('最近活跃员工', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text('姓名', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('工号', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('部门', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('职位', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: _employees.take(10).map((e) {
                final isOnline = e['is_online'] == 1;
                return DataRow(cells: [
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text((e['name'] ?? '?')[0], style: const TextStyle(fontSize: 12, color: AppColors.primary))),
                    const SizedBox(width: 8), Text(e['name'] ?? ''),
                  ])),
                  DataCell(Text(e['employee_no'] ?? '')),
                  DataCell(Text(e['department'] ?? '')),
                  DataCell(Text(e['position'] ?? '')),
                  DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: (isOnline ? AppColors.success : AppColors.offline).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(isOnline ? '在线' : '离线', style: TextStyle(fontSize: 12, color: isOnline ? AppColors.success : AppColors.offline)),
                  )),
                ]);
              }).toList(),
            )),
          ]),
        ),
      ]),
    );
  }
}
