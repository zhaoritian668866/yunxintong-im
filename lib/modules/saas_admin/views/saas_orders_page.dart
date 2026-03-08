import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class SaasOrdersPage extends StatefulWidget {
  const SaasOrdersPage({super.key});

  @override
  State<SaasOrdersPage> createState() => _SaasOrdersPageState();
}

class _SaasOrdersPageState extends State<SaasOrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _statusFilter = '全部';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final res = await ApiService.saasGetOrders(
      status: _statusFilter == '全部' ? null : _statusFilterValue,
      keyword: _searchQuery.isNotEmpty ? _searchQuery : null,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess) {
          final d = res.data;
          if (d is Map) {
            _orders = List<Map<String, dynamic>>.from(d['list'] ?? []);
          } else if (d is List) {
            _orders = List<Map<String, dynamic>>.from(d);
          }
        }
      });
    }
  }

  String? get _statusFilterValue {
    switch (_statusFilter) {
      case '待支付': return 'pending';
      case '已支付': return 'paid';
      case '已完成': return 'completed';
      case '已取消': return 'cancelled';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 工具栏
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 280, child: TextField(
            decoration: InputDecoration(
              hintText: '搜索订单号或租户名称...',
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) {
              _searchQuery = v;
              _loadOrders();
            },
          )),
          _buildFilterChip('全部'),
          _buildFilterChip('待支付'),
          _buildFilterChip('已支付'),
          _buildFilterChip('已完成'),
          _buildFilterChip('已取消'),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _showCreateOrderDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('创建订单'),
          ),
        ]),
        const SizedBox(height: 20),
        // 统计卡片
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 800 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildStatCard('全部订单', '${_orders.length}', Icons.receipt_long, AppColors.primary),
              _buildStatCard('待支付', '${_orders.where((o) => o['status'] == 'pending').length}', Icons.hourglass_empty, AppColors.warning),
              _buildStatCard('已完成', '${_orders.where((o) => o['status'] == 'completed').length}', Icons.check_circle, AppColors.success),
              _buildStatCard('总收入', _calcTotalRevenue(), Icons.monetization_on, const Color(0xFF9C27B0)),
            ],
          );
        }),
        const SizedBox(height: 20),
        // 订单列表
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: _isLoading
              ? const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
              : _orders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(48),
                      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('暂无订单记录', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ])),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.background),
                        columns: const [
                          DataColumn(label: Text('订单号', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('租户', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('套餐', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('金额', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('周期', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('创建时间', style: TextStyle(fontWeight: FontWeight.w600))),
                          DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        rows: _orders.map((o) => DataRow(cells: [
                          DataCell(Text(o['order_no'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace', fontSize: 12))),
                          DataCell(Text(o['tenant_name'] ?? '')),
                          DataCell(_buildPlanBadge(o['plan'] ?? '')),
                          DataCell(Text('¥${o['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF9C27B0)))),
                          DataCell(Text(_formatPeriod(o['period'] ?? ''))),
                          DataCell(_buildStatusChip(o['status'] ?? '')),
                          DataCell(Text(_formatTime(o['created_at'] ?? ''), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary), onPressed: () => _showOrderDetail(o), tooltip: '查看详情'),
                            if (o['status'] == 'pending') ...[
                              IconButton(icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success), onPressed: () => _confirmOrder(o), tooltip: '确认支付'),
                              IconButton(icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error), onPressed: () => _cancelOrder(o), tooltip: '取消'),
                            ],
                          ])),
                        ])).toList(),
                      ),
                    ),
        ),
        const SizedBox(height: 16),
        Text('共 ${_orders.length} 条记录', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
      ]),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = label);
        _loadOrders();
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontSize: 13),
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case 'pending': color = AppColors.warning; text = '待支付';
      case 'paid': color = AppColors.info; text = '已支付';
      case 'completed': color = AppColors.success; text = '已完成';
      case 'cancelled': color = AppColors.error; text = '已取消';
      case 'refunded': color = Colors.purple; text = '已退款';
      default: color = AppColors.textSecondary; text = '未知';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPlanBadge(String plan) {
    Color color;
    String text;
    switch (plan) {
      case 'basic': color = AppColors.info; text = '基础版';
      case 'professional': color = AppColors.primary; text = '专业版';
      case 'enterprise': color = const Color(0xFF9C27B0); text = '企业版';
      default: color = AppColors.textSecondary; text = plan;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }

  String _formatPeriod(String period) {
    switch (period) {
      case 'monthly': return '月付';
      case 'quarterly': return '季付';
      case 'yearly': return '年付';
      default: return period;
    }
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    try {
      final dt = DateTime.parse(time);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return time;
    }
  }

  String _calcTotalRevenue() {
    double total = 0;
    for (final o in _orders) {
      if (o['status'] == 'completed' || o['status'] == 'paid') {
        total += (o['amount'] ?? 0).toDouble();
      }
    }
    return '¥${total.toStringAsFixed(0)}';
  }

  void _showCreateOrderDialog() {
    final tenantIdCtrl = TextEditingController();
    String selectedPlan = 'basic';
    String selectedPeriod = 'monthly';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.add_circle_outline, color: AppColors.primary),
        SizedBox(width: 8),
        Text('创建订单'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: tenantIdCtrl,
          decoration: InputDecoration(
            labelText: '租户企业ID *',
            hintText: '输入企业ID',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.business),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedPlan,
          decoration: InputDecoration(
            labelText: '套餐类型',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.card_membership),
          ),
          items: const [
            DropdownMenuItem(value: 'basic', child: Text('基础版 - ¥299/月')),
            DropdownMenuItem(value: 'professional', child: Text('专业版 - ¥599/月')),
            DropdownMenuItem(value: 'enterprise', child: Text('企业版 - ¥999/月')),
          ],
          onChanged: (v) => setDialogState(() => selectedPlan = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedPeriod,
          decoration: InputDecoration(
            labelText: '付费周期',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.calendar_today),
          ),
          items: const [
            DropdownMenuItem(value: 'monthly', child: Text('月付')),
            DropdownMenuItem(value: 'quarterly', child: Text('季付 (9折)')),
            DropdownMenuItem(value: 'yearly', child: Text('年付 (8折)')),
          ],
          onChanged: (v) => setDialogState(() => selectedPeriod = v!),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('预计金额: ¥${_calcOrderAmount(selectedPlan, selectedPeriod)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
          ]),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (tenantIdCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          final res = await ApiService.saasCreateOrder({
            'enterprise_id': tenantIdCtrl.text,
            'plan': selectedPlan,
            'period': selectedPeriod,
            'amount': _calcOrderAmount(selectedPlan, selectedPeriod),
          });
          if (res.isSuccess) {
            _loadOrders();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('订单创建成功'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(res.message.isNotEmpty ? res.message : '创建失败'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              );
            }
          }
        }, child: const Text('创建订单')),
      ],
    )));
  }

  int _calcOrderAmount(String plan, String period) {
    int base;
    switch (plan) {
      case 'basic': base = 299;
      case 'professional': base = 599;
      case 'enterprise': base = 999;
      default: base = 299;
    }
    switch (period) {
      case 'monthly': return base;
      case 'quarterly': return (base * 3 * 0.9).round();
      case 'yearly': return (base * 12 * 0.8).round();
      default: return base;
    }
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.receipt_long, color: AppColors.primary),
        const SizedBox(width: 8),
        Text('订单详情 #${order['order_no'] ?? ''}'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 450, child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildDetailRow('订单号', order['order_no'] ?? ''),
        _buildDetailRow('租户', order['tenant_name'] ?? ''),
        _buildDetailRow('企业ID', order['enterprise_id'] ?? ''),
        _buildDetailRow('套餐', _planName(order['plan'] ?? '')),
        _buildDetailRow('金额', '¥${order['amount'] ?? 0}'),
        _buildDetailRow('付费周期', _formatPeriod(order['period'] ?? '')),
        _buildDetailRow('状态', _statusName(order['status'] ?? '')),
        _buildDetailRow('创建时间', _formatTime(order['created_at'] ?? '')),
        if (order['paid_at'] != null) _buildDetailRow('支付时间', _formatTime(order['paid_at'] ?? '')),
        if (order['remark'] != null && order['remark'].toString().isNotEmpty) _buildDetailRow('备注', order['remark']),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
      ],
    ));
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }

  String _planName(String plan) {
    switch (plan) {
      case 'basic': return '基础版';
      case 'professional': return '专业版';
      case 'enterprise': return '企业版';
      default: return plan;
    }
  }

  String _statusName(String status) {
    switch (status) {
      case 'pending': return '待支付';
      case 'paid': return '已支付';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      case 'refunded': return '已退款';
      default: return status;
    }
  }

  void _confirmOrder(Map<String, dynamic> order) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.check_circle, color: AppColors.success),
        SizedBox(width: 8),
        Text('确认支付'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text('确认订单 #${order['order_no']} 已完成支付？\n金额: ¥${order['amount']}'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.saasUpdateOrder(order['id'], {'status': 'completed'});
            if (res.isSuccess) {
              _loadOrders();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('订单已确认完成'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                );
              }
            }
          },
          child: const Text('确认支付'),
        ),
      ],
    ));
  }

  void _cancelOrder(Map<String, dynamic> order) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.cancel, color: AppColors.error),
        SizedBox(width: 8),
        Text('取消订单'),
      ]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text('确定要取消订单 #${order['order_no']} 吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('返回')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.saasUpdateOrder(order['id'], {'status': 'cancelled'});
            if (res.isSuccess) {
              _loadOrders();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('订单已取消'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                );
              }
            }
          },
          child: const Text('确认取消'),
        ),
      ],
    ));
  }
}
