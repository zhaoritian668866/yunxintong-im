import 'dart:math';
import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key});
  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('工作台'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 常用应用
          _buildSection('常用应用', [
            _AppItem(icon: Icons.event_note, label: '日程', color: AppColors.primary, onTap: () => _openSchedule(context)),
            _AppItem(icon: Icons.task_alt, label: '任务', color: AppColors.success, onTap: () => _openTasks(context)),
            _AppItem(icon: Icons.cloud_upload, label: '云盘', color: AppColors.warning, onTap: () => _openCloudDrive(context)),
            _AppItem(icon: Icons.how_to_vote, label: '审批', color: AppColors.info, onTap: () => _openApproval(context)),
          ]),
          const SizedBox(height: 16),
          // 办公工具
          _buildSection('办公工具', [
            _AppItem(icon: Icons.access_time, label: '考勤', color: AppColors.primary, onTap: () => _openAttendance(context)),
            _AppItem(icon: Icons.meeting_room, label: '会议室', color: AppColors.success, onTap: () => _openMeetingRoom(context)),
            _AppItem(icon: Icons.announcement, label: '公告', color: AppColors.error, onTap: () => _openAnnouncements(context)),
            _AppItem(icon: Icons.poll, label: '投票', color: AppColors.warning, onTap: () => _openVoting(context)),
            _AppItem(icon: Icons.receipt_long, label: '报销', color: AppColors.info, onTap: () => _openExpense(context)),
            _AppItem(icon: Icons.calendar_month, label: '日历', color: AppColors.primary, onTap: () => _openCalendar(context)),
          ]),
          const SizedBox(height: 16),
          // 数据统计
          _buildSection('数据统计', [
            _AppItem(icon: Icons.bar_chart, label: '报表', color: AppColors.primary, onTap: () => _openReports(context)),
            _AppItem(icon: Icons.pie_chart, label: '分析', color: AppColors.success, onTap: () => _openAnalytics(context)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
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
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item.icon, color: item.color, size: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(item.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 日程管理 ====================
  void _openSchedule(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _SchedulePage()));
  }

  // ==================== 任务管理 ====================
  void _openTasks(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _TasksPage()));
  }

  // ==================== 云盘 ====================
  void _openCloudDrive(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _CloudDrivePage()));
  }

  // ==================== 审批 ====================
  void _openApproval(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _ApprovalPage()));
  }

  // ==================== 考勤 ====================
  void _openAttendance(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _AttendancePage()));
  }

  // ==================== 会议室 ====================
  void _openMeetingRoom(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _MeetingRoomPage()));
  }

  // ==================== 公告 ====================
  void _openAnnouncements(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _AnnouncementsPage()));
  }

  // ==================== 投票 ====================
  void _openVoting(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _VotingPage()));
  }

  // ==================== 报销 ====================
  void _openExpense(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _ExpensePage()));
  }

  // ==================== 日历 ====================
  void _openCalendar(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _CalendarPage()));
  }

  // ==================== 报表 ====================
  void _openReports(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _ReportsPage()));
  }

  // ==================== 分析 ====================
  void _openAnalytics(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _AnalyticsPage()));
  }
}

class _AppItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _AppItem({required this.icon, required this.label, required this.color, this.onTap});
}

// ==================== 日程页面 ====================
class _SchedulePage extends StatefulWidget {
  const _SchedulePage();
  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  final List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    _schedules.addAll([
      {'title': '团队周会', 'time': '09:00 - 10:00', 'date': '今天', 'color': AppColors.primary, 'location': '3号会议室'},
      {'title': '产品评审', 'time': '14:00 - 15:30', 'date': '今天', 'color': AppColors.success, 'location': '线上'},
      {'title': '客户拜访', 'time': '10:00 - 11:00', 'date': '明天', 'color': AppColors.warning, 'location': '客户办公室'},
    ]);
  }

  void _addSchedule() {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('新建日程'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: '日程标题', hintText: '例如：团队周会', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 12),
          TextField(controller: locationCtrl, decoration: InputDecoration(labelText: '地点', hintText: '例如：3号会议室', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: startTime);
                if (t != null) setDialogState(() => startTime = t);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [const Icon(Icons.access_time, size: 18), const SizedBox(width: 6), Text('${startTime.format(ctx)}')]),
              ),
            )),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-')),
            Expanded(child: InkWell(
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: endTime);
                if (t != null) setDialogState(() => endTime = t);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [const Icon(Icons.access_time, size: 18), const SizedBox(width: 6), Text('${endTime.format(ctx)}')]),
              ),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              setState(() {
                _schedules.insert(0, {
                  'title': titleCtrl.text.trim(),
                  'time': '${startTime.format(ctx)} - ${endTime.format(ctx)}',
                  'date': '今天',
                  'color': [AppColors.primary, AppColors.success, AppColors.warning, AppColors.info][_schedules.length % 4],
                  'location': locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : '未指定',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('日程已创建'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            },
            child: const Text('创建'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日程管理'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addSchedule)]),
      body: _schedules.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('暂无日程', style: TextStyle(color: AppColors.textSecondary)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _schedules.length,
            itemBuilder: (_, i) {
              final s = _schedules[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: s['color'] as Color, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${s['date']} ${s['time']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(s['location'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () => setState(() => _schedules.removeAt(i)),
                  ),
                ]),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(onPressed: _addSchedule, child: const Icon(Icons.add)),
    );
  }
}

// ==================== 任务页面 ====================
class _TasksPage extends StatefulWidget {
  const _TasksPage();
  @override
  State<_TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<_TasksPage> {
  final List<Map<String, dynamic>> _tasks = [
    {'title': '完成Q1季度报告', 'status': 'doing', 'priority': 'high', 'deadline': '2026-03-10'},
    {'title': '更新产品文档', 'status': 'todo', 'priority': 'medium', 'deadline': '2026-03-15'},
    {'title': '代码审查', 'status': 'done', 'priority': 'low', 'deadline': '2026-03-08'},
    {'title': '客户需求分析', 'status': 'doing', 'priority': 'high', 'deadline': '2026-03-12'},
  ];

  void _addTask() {
    final titleCtrl = TextEditingController();
    String priority = 'medium';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('新建任务'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: '任务标题', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: InputDecoration(labelText: '优先级', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            items: const [
              DropdownMenuItem(value: 'high', child: Text('高')),
              DropdownMenuItem(value: 'medium', child: Text('中')),
              DropdownMenuItem(value: 'low', child: Text('低')),
            ],
            onChanged: (v) => setDialogState(() => priority = v ?? 'medium'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              setState(() => _tasks.insert(0, {'title': titleCtrl.text.trim(), 'status': 'todo', 'priority': priority, 'deadline': '2026-03-20'}));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已创建'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            },
            child: const Text('创建'),
          ),
        ],
      )),
    );
  }

  Color _priorityColor(String p) => p == 'high' ? AppColors.error : (p == 'medium' ? AppColors.warning : AppColors.success);
  String _priorityLabel(String p) => p == 'high' ? '高' : (p == 'medium' ? '中' : '低');
  String _statusLabel(String s) => s == 'done' ? '已完成' : (s == 'doing' ? '进行中' : '待开始');
  Color _statusColor(String s) => s == 'done' ? AppColors.success : (s == 'doing' ? AppColors.primary : AppColors.textSecondary);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('任务管理'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addTask)]),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (_, i) {
          final t = _tasks[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
            child: Row(children: [
              Checkbox(
                value: t['status'] == 'done',
                onChanged: (v) => setState(() => t['status'] = v == true ? 'done' : 'todo'),
                activeColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['title'], style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, decoration: t['status'] == 'done' ? TextDecoration.lineThrough : null, color: t['status'] == 'done' ? AppColors.textSecondary : AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _priorityColor(t['priority']).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(_priorityLabel(t['priority']), style: TextStyle(fontSize: 10, color: _priorityColor(t['priority']), fontWeight: FontWeight.w500))),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _statusColor(t['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(_statusLabel(t['status']), style: TextStyle(fontSize: 10, color: _statusColor(t['status']), fontWeight: FontWeight.w500))),
                  const SizedBox(width: 8),
                  Text('截止: ${t['deadline']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ])),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') setState(() => _tasks.removeAt(i));
                  else setState(() => t['status'] = v);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'todo', child: Text('待开始')),
                  const PopupMenuItem(value: 'doing', child: Text('进行中')),
                  const PopupMenuItem(value: 'done', child: Text('已完成')),
                  const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addTask, child: const Icon(Icons.add)),
    );
  }
}

// ==================== 云盘页面 ====================
class _CloudDrivePage extends StatefulWidget {
  const _CloudDrivePage();
  @override
  State<_CloudDrivePage> createState() => _CloudDrivePageState();
}

class _CloudDrivePageState extends State<_CloudDrivePage> {
  final List<Map<String, dynamic>> _files = [
    {'name': 'Q1季度报告.docx', 'size': '2.3 MB', 'icon': Icons.description, 'color': AppColors.primary, 'date': '2026-03-05'},
    {'name': '产品设计稿.psd', 'size': '15.8 MB', 'icon': Icons.image, 'color': AppColors.warning, 'date': '2026-03-04'},
    {'name': '会议录音.mp3', 'size': '8.1 MB', 'icon': Icons.audiotrack, 'color': AppColors.success, 'date': '2026-03-03'},
    {'name': '项目计划.xlsx', 'size': '1.2 MB', 'icon': Icons.table_chart, 'color': AppColors.info, 'date': '2026-03-02'},
    {'name': '培训资料', 'size': '3 个文件', 'icon': Icons.folder, 'color': AppColors.warning, 'date': '2026-03-01'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('云盘'), actions: [
        IconButton(icon: const Icon(Icons.create_new_folder), tooltip: '新建文件夹', onPressed: _createFolder),
        IconButton(icon: const Icon(Icons.upload_file), tooltip: '上传文件', onPressed: _uploadFile),
      ]),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final f = _files[i];
          return ListTile(
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: (f['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(f['icon'] as IconData, color: f['color'] as Color, size: 22)),
            title: Text(f['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('${f['size']} · ${f['date']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') setState(() => _files.removeAt(i));
                else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$v: ${f['name']}'), behavior: SnackBarBehavior.floating));
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: '下载', child: Text('下载')),
                const PopupMenuItem(value: '重命名', child: Text('重命名')),
                const PopupMenuItem(value: '分享', child: Text('分享')),
                const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: AppColors.error))),
              ],
            ),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开: ${f['name']}'), behavior: SnackBarBehavior.floating)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _uploadFile, child: const Icon(Icons.upload)),
    );
  }

  void _createFolder() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('新建文件夹'),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: '文件夹名称', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              setState(() => _files.insert(0, {'name': ctrl.text.trim(), 'size': '空', 'icon': Icons.folder, 'color': AppColors.warning, 'date': '今天'}));
              Navigator.pop(ctx);
            }
          }, child: const Text('创建')),
        ],
      ),
    );
  }

  void _uploadFile() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文件上传功能（Web环境暂不支持文件选择器）'), behavior: SnackBarBehavior.floating));
  }
}

// ==================== 审批页面 ====================
class _ApprovalPage extends StatefulWidget {
  const _ApprovalPage();
  @override
  State<_ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<_ApprovalPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final List<Map<String, dynamic>> _pending = [
    {'title': '请假申请 - 张三', 'type': '请假', 'time': '2026-03-07', 'detail': '事假2天'},
    {'title': '报销申请 - 李四', 'type': '报销', 'time': '2026-03-06', 'detail': '差旅费用 ¥3,200'},
  ];
  final List<Map<String, dynamic>> _approved = [
    {'title': '加班申请 - 王五', 'type': '加班', 'time': '2026-03-05', 'detail': '周末加班', 'result': '已通过'},
  ];

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('审批'), bottom: TabBar(controller: _tabCtrl, tabs: const [Tab(text: '待审批'), Tab(text: '已审批')], indicatorColor: Colors.white)),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildList(_pending, true),
        _buildList(_approved, false),
      ]),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, bool canApprove) {
    if (items.isEmpty) return const Center(child: Text('暂无审批', style: TextStyle(color: AppColors.textSecondary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(a['type'], style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500))),
              const SizedBox(width: 8),
              Expanded(child: Text(a['title'], style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(a['time'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(a['detail'], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (canApprove) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(onPressed: () {
                  setState(() { items.removeAt(i); _approved.add({...a, 'result': '已拒绝'}); });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拒绝'), behavior: SnackBarBehavior.floating));
                }, style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)), child: const Text('拒绝')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {
                  setState(() { items.removeAt(i); _approved.add({...a, 'result': '已通过'}); });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已通过'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
                }, child: const Text('通过')),
              ]),
            ] else if (a['result'] != null) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: a['result'] == '已通过' ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(a['result'], style: TextStyle(fontSize: 12, color: a['result'] == '已通过' ? AppColors.success : AppColors.error, fontWeight: FontWeight.w500))),
            ],
          ]),
        );
      },
    );
  }
}

// ==================== 考勤页面 ====================
class _AttendancePage extends StatefulWidget {
  const _AttendancePage();
  @override
  State<_AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<_AttendancePage> {
  bool _checkedIn = false;
  bool _checkedOut = false;
  String? _checkInTime;
  String? _checkOutTime;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('考勤打卡')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${now.year}年${now.month}月${now.day}日', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(['周日','周一','周二','周三','周四','周五','周六'][now.weekday % 7], style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 40),
          // 上班打卡
          GestureDetector(
            onTap: _checkedIn ? null : () {
              setState(() { _checkedIn = true; _checkInTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}'; });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上班打卡成功: $_checkInTime'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            },
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _checkedIn ? AppColors.success : AppColors.primary,
                boxShadow: [BoxShadow(color: (_checkedIn ? AppColors.success : AppColors.primary).withOpacity(0.3), blurRadius: 20, spreadRadius: 4)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_checkedIn ? Icons.check : Icons.fingerprint, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(_checkedIn ? '已签到' : '上班打卡', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                if (_checkInTime != null) Text(_checkInTime!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(height: 30),
          // 下班打卡
          GestureDetector(
            onTap: _checkedOut ? null : () {
              setState(() { _checkedOut = true; _checkOutTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}'; });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下班打卡成功: $_checkOutTime'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
            },
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _checkedOut ? AppColors.success : AppColors.warning,
                boxShadow: [BoxShadow(color: (_checkedOut ? AppColors.success : AppColors.warning).withOpacity(0.3), blurRadius: 16, spreadRadius: 2)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_checkedOut ? Icons.check : Icons.fingerprint, color: Colors.white, size: 30),
                const SizedBox(height: 4),
                Text(_checkedOut ? '已签退' : '下班打卡', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                if (_checkOutTime != null) Text(_checkOutTime!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _statItem('本月出勤', '18天'),
              _statItem('迟到', '0次'),
              _statItem('早退', '0次'),
              _statItem('请假', '1天'),
            ]),
          ),
        ]),
      )),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]);
  }
}

// ==================== 会议室页面 ====================
class _MeetingRoomPage extends StatelessWidget {
  const _MeetingRoomPage();
  @override
  Widget build(BuildContext context) {
    final rooms = [
      {'name': '1号会议室', 'capacity': '8人', 'status': '空闲', 'equipment': 'WiFi、投影仪、白板'},
      {'name': '2号会议室', 'capacity': '12人', 'status': '使用中', 'equipment': 'WiFi、投影仪、视频会议'},
      {'name': '3号会议室', 'capacity': '20人', 'status': '空闲', 'equipment': 'WiFi、投影仪、音响'},
      {'name': '培训室', 'capacity': '50人', 'status': '已预约', 'equipment': 'WiFi、投影仪、音响、录播'},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('会议室预约')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rooms.length,
        itemBuilder: (_, i) {
          final r = rooms[i];
          final isFree = r['status'] == '空闲';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
            child: Row(children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(color: (isFree ? AppColors.success : AppColors.textSecondary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.meeting_room, color: isFree ? AppColors.success : AppColors.textSecondary)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(r['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (isFree ? AppColors.success : AppColors.warning).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(r['status']!, style: TextStyle(fontSize: 11, color: isFree ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w500))),
                ]),
                const SizedBox(height: 4),
                Text('容纳: ${r['capacity']} | ${r['equipment']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              ElevatedButton(
                onPressed: isFree ? () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['name']} 预约成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
                } : null,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero),
                child: Text(isFree ? '预约' : '已占用', style: const TextStyle(fontSize: 12)),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ==================== 公告页面 ====================
class _AnnouncementsPage extends StatelessWidget {
  const _AnnouncementsPage();
  @override
  Widget build(BuildContext context) {
    final announcements = [
      {'title': '关于2026年清明节放假安排的通知', 'date': '2026-03-08', 'author': '行政部', 'content': '根据国务院办公厅通知，2026年清明节放假安排如下：4月4日至6日放假调休，共3天。'},
      {'title': '公司年度体检通知', 'date': '2026-03-05', 'author': '人力资源部', 'content': '公司将于3月15日-31日组织年度体检，请各部门员工按时参加。'},
      {'title': '办公区域WiFi升级通知', 'date': '2026-03-01', 'author': 'IT部', 'content': '为提升网络体验，IT部将于本周末对办公区域WiFi进行升级改造。'},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('公告')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (_, i) {
          final a = announcements[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (i == 0) Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4)),
                  child: const Text('最新', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500))),
                Expanded(child: Text(a['title']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              ]),
              const SizedBox(height: 8),
              Text(a['content']!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                Text(a['author']!, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                const Spacer(),
                Text(a['date']!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ]),
          );
        },
      ),
    );
  }
}

// ==================== 投票页面 ====================
class _VotingPage extends StatefulWidget {
  const _VotingPage();
  @override
  State<_VotingPage> createState() => _VotingPageState();
}

class _VotingPageState extends State<_VotingPage> {
  final List<Map<String, dynamic>> _votes = [
    {'title': '团建活动方案投票', 'options': ['方案A: 户外拓展', '方案B: 温泉度假', '方案C: 城市探索'], 'counts': [12, 8, 5], 'voted': -1, 'deadline': '2026-03-15'},
    {'title': '午餐供应商选择', 'options': ['供应商A', '供应商B', '供应商C'], 'counts': [20, 15, 10], 'voted': -1, 'deadline': '2026-03-10'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投票')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _votes.length,
        itemBuilder: (_, i) {
          final v = _votes[i];
          final total = (v['counts'] as List<int>).fold<int>(0, (a, b) => a + b);
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v['title'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 4),
              Text('截止: ${v['deadline']} | 已投: $total票', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ...List.generate((v['options'] as List).length, (j) {
                final pct = total > 0 ? (v['counts'][j] / total) : 0.0;
                final isVoted = v['voted'] == j;
                return GestureDetector(
                  onTap: v['voted'] >= 0 ? null : () {
                    setState(() { v['voted'] = j; v['counts'][j]++; });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投票成功'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isVoted ? AppColors.primary.withOpacity(0.05) : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isVoted ? AppColors.primary : Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v['options'][j], style: TextStyle(fontWeight: isVoted ? FontWeight.w600 : FontWeight.normal)),
                        const SizedBox(height: 4),
                        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(isVoted ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5)))),
                      ])),
                      const SizedBox(width: 12),
                      Text('${(pct * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.w600, color: isVoted ? AppColors.primary : AppColors.textSecondary)),
                    ]),
                  ),
                );
              }),
            ]),
          );
        },
      ),
    );
  }
}

// ==================== 报销页面 ====================
class _ExpensePage extends StatefulWidget {
  const _ExpensePage();
  @override
  State<_ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<_ExpensePage> {
  final List<Map<String, dynamic>> _expenses = [
    {'title': '差旅报销', 'amount': 3200.0, 'status': '审批中', 'date': '2026-03-05', 'category': '差旅'},
    {'title': '办公用品采购', 'amount': 580.0, 'status': '已通过', 'date': '2026-03-01', 'category': '办公'},
    {'title': '客户招待费', 'amount': 1500.0, 'status': '已报销', 'date': '2026-02-28', 'category': '招待'},
  ];

  void _addExpense() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = '差旅';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('新建报销'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: InputDecoration(labelText: '报销标题', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 12),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '金额 (元)', prefixText: '¥ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category,
            decoration: InputDecoration(labelText: '类别', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            items: ['差旅', '办公', '招待', '交通', '其他'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setDialogState(() => category = v ?? '差旅'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () {
            if (titleCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
            setState(() => _expenses.insert(0, {'title': titleCtrl.text.trim(), 'amount': double.tryParse(amountCtrl.text) ?? 0, 'status': '审批中', 'date': '今天', 'category': category}));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报销申请已提交'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.success));
          }, child: const Text('提交')),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('报销'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addExpense)]),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _expenses.length,
        itemBuilder: (_, i) {
          final e = _expenses[i];
          Color statusColor = e['status'] == '已报销' ? AppColors.success : (e['status'] == '已通过' ? AppColors.primary : AppColors.warning);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long, color: AppColors.warning)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(e['status'], style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w500))),
                  const SizedBox(width: 8),
                  Text('${e['category']} · ${e['date']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ])),
              Text('¥${(e['amount'] as double).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addExpense, child: const Icon(Icons.add)),
    );
  }
}

// ==================== 日历页面 ====================
class _CalendarPage extends StatelessWidget {
  const _CalendarPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('日历')),
      body: Column(children: [
        CalendarDatePicker(
          initialDate: DateTime.now(),
          firstDate: DateTime(2025),
          lastDate: DateTime(2027),
          onDateChanged: (date) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择日期: ${date.year}-${date.month}-${date.day}'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('今日日程', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _calendarEvent('09:00', '团队周会', AppColors.primary),
            _calendarEvent('14:00', '产品评审', AppColors.success),
            _calendarEvent('16:00', '1对1沟通', AppColors.warning),
          ],
        )),
      ]),
    );
  }

  Widget _calendarEvent(String time, String title, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: color, width: 3))),
      child: Row(children: [
        Text(time, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ==================== 报表页面 ====================
class _ReportsPage extends StatelessWidget {
  const _ReportsPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据报表')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _reportCard('消息统计', '本月消息总量', '12,580', Icons.message, AppColors.primary, '+15.2%'),
          _reportCard('活跃用户', '本月活跃用户数', '86', Icons.people, AppColors.success, '+8.5%'),
          _reportCard('在线时长', '人均在线时长', '6.2h', Icons.access_time, AppColors.warning, '+3.1%'),
          _reportCard('文件传输', '本月文件传输量', '2.3 GB', Icons.cloud_upload, AppColors.info, '+22.7%'),
        ],
      ),
    );
  }

  Widget _reportCard(String title, String subtitle, String value, IconData icon, Color color, String change) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 28)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.trending_up, size: 14, color: AppColors.success),
            const SizedBox(width: 2),
            Text(change, style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w500)),
          ]),
        ]),
      ]),
    );
  }
}

// ==================== 分析页面 ====================
class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据分析')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('消息趋势（近7天）', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: CustomPaint(painter: _BarChartPainter()),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('部门活跃度排名', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              _deptRank('技术部', 0.92, AppColors.primary),
              _deptRank('产品部', 0.85, AppColors.success),
              _deptRank('市场部', 0.78, AppColors.warning),
              _deptRank('行政部', 0.65, AppColors.info),
              _deptRank('财务部', 0.52, AppColors.textSecondary),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _deptRank(String name, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        SizedBox(width: 60, child: Text(name, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 12, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation(color)))),
        const SizedBox(width: 8),
        Text('${(pct * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
      ]),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final values = [180, 220, 195, 280, 250, 310, 265];
    final labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final maxVal = 350.0;
    final barWidth = size.width / (values.length * 2);
    final colors = [AppColors.primary, AppColors.primary, AppColors.primary, AppColors.success, AppColors.primary, AppColors.success, AppColors.primary];

    for (int i = 0; i < values.length; i++) {
      final x = i * (size.width / values.length) + barWidth / 2;
      final barHeight = (values[i] / maxVal) * (size.height - 30);
      final rect = Rect.fromLTWH(x, size.height - 30 - barHeight, barWidth, barHeight);
      final paint = Paint()..color = colors[i].withOpacity(0.7)..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);

      // 标签
      final tp = TextPainter(text: TextSpan(text: labels[i], style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, size.height - 20));

      // 数值
      final vp = TextPainter(text: TextSpan(text: '${values[i]}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)), textDirection: TextDirection.ltr);
      vp.layout();
      vp.paint(canvas, Offset(x + barWidth / 2 - vp.width / 2, size.height - 30 - barHeight - 14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
