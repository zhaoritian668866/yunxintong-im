import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class EnterpriseChatRecordsPage extends StatefulWidget {
  const EnterpriseChatRecordsPage({super.key});

  @override
  State<EnterpriseChatRecordsPage> createState() => _EnterpriseChatRecordsPageState();
}

class _EnterpriseChatRecordsPageState extends State<EnterpriseChatRecordsPage> {
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedUser = '全部用户';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final recordsRes = await ApiService.enterpriseGetChatRecords();
    final empRes = await ApiService.enterpriseGetEmployees();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (recordsRes.isSuccess) _records = List<Map<String, dynamic>>.from(recordsRes.data?['records'] ?? []);
        if (empRes.isSuccess) _employees = List<Map<String, dynamic>>.from(empRes.data?['employees'] ?? []);
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    var list = _records;
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) => (r['content'] ?? '').toString().contains(_searchQuery) || (r['sender_name'] ?? '').toString().contains(_searchQuery)).toList();
    }
    if (_selectedUser != '全部用户') {
      list = list.where((r) => r['sender_name'] == _selectedUser || r['receiver_name'] == _selectedUser).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final records = _filteredRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 搜索和筛选
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 300, child: TextField(
            decoration: InputDecoration(hintText: '搜索消息内容或发送者...', prefixIcon: const Icon(Icons.search, size: 20), contentPadding: const EdgeInsets.symmetric(vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            onChanged: (v) => setState(() => _searchQuery = v),
          )),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _selectedUser,
              items: ['全部用户', ..._employees.map((e) => e['name'] as String? ?? '')].map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: (v) => setState(() => _selectedUser = v ?? '全部用户'),
            ))),
          OutlinedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 18), label: const Text('刷新')),
        ]),
        const SizedBox(height: 20),
        // 聊天记录列表
        Container(
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
          child: records.isEmpty
              ? Padding(padding: const EdgeInsets.all(48), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('暂无聊天记录', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ])))
              : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.background),
                  columns: const [
                    DataColumn(label: Text('发送者', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('接收者', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('消息类型', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('消息内容', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('发送时间', style: TextStyle(fontWeight: FontWeight.w600))),
                    DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                  rows: records.map((r) => DataRow(cells: [
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(radius: 14, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text((r['sender_name'] ?? '?')[0], style: const TextStyle(fontSize: 12, color: AppColors.primary))),
                      const SizedBox(width: 8), Text(r['sender_name'] ?? ''),
                    ])),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(radius: 14, backgroundColor: AppColors.info.withValues(alpha: 0.15), child: Text((r['receiver_name'] ?? '?')[0], style: const TextStyle(fontSize: 12, color: AppColors.info))),
                      const SizedBox(width: 8), Text(r['receiver_name'] ?? ''),
                    ])),
                    DataCell(_buildMsgTypeChip(r['msg_type'] ?? 'text')),
                    DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: Text(r['content'] ?? '', overflow: TextOverflow.ellipsis))),
                    DataCell(Text(_formatTime(r['created_at'] ?? ''), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    DataCell(_buildStatusChip(r['is_read'] == 1)),
                  ])).toList(),
                )),
        ),
        const SizedBox(height: 16),
        Text('共 ${records.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildMsgTypeChip(String type) {
    IconData icon; String text; Color color;
    switch (type) {
      case 'image': icon = Icons.image; text = '图片'; color = AppColors.success;
      case 'file': icon = Icons.attach_file; text = '文件'; color = AppColors.warning;
      case 'voice': icon = Icons.mic; text = '语音'; color = AppColors.info;
      default: icon = Icons.text_fields; text = '文本'; color = AppColors.primary;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color), const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildStatusChip(bool isRead) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (isRead ? AppColors.success : AppColors.warning).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(isRead ? '已读' : '未读', style: TextStyle(fontSize: 11, color: isRead ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w600)));
  }

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return isoTime; }
  }
}
