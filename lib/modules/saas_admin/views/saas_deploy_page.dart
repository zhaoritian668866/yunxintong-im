import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class SaasDeployPage extends StatefulWidget {
  const SaasDeployPage({super.key});
  @override
  State<SaasDeployPage> createState() => _SaasDeployPageState();
}

class _SaasDeployPageState extends State<SaasDeployPage> {
  int _currentStep = 0;
  String? _selectedTenantId;
  Map<String, dynamic>? _selectedTenant;
  String? _selectedServerId;
  Map<String, dynamic>? _selectedServer;
  List<Map<String, dynamic>> _undeployedTenants = [];
  List<Map<String, dynamic>> _availableServers = [];
  List<Map<String, dynamic>> _allTenants = [];
  bool _isLoading = true;
  bool _isDeploying = false;
  double _deployProgress = 0;
  final List<String> _deployLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; });
    final undeployedRes = await ApiService.saasGetUndeployedTenants();
    final serversRes = await ApiService.saasGetAvailableServers();
    final allTenantsRes = await ApiService.saasGetTenants();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (undeployedRes.isSuccess) {
        final d = undeployedRes.data;
        _undeployedTenants = List<Map<String, dynamic>>.from(d is List ? d : (d is Map ? (d['list'] ?? []) : []));
      }
      if (serversRes.isSuccess) {
        final d = serversRes.data;
        _availableServers = List<Map<String, dynamic>>.from(d is List ? d : (d is Map ? (d['list'] ?? []) : []));
      }
      if (allTenantsRes.isSuccess) {
        final d = allTenantsRes.data;
        _allTenants = List<Map<String, dynamic>>.from(d is List ? d : (d is Map ? (d['list'] ?? []) : []));
      }
    });
  }

  String _planLabel(String plan) {
    switch (plan) {
      case 'basic': return '基础版';
      case 'standard': return '标准版';
      case 'professional': return '专业版';
      case 'enterprise': return '企业版';
      default: return plan;
    }
  }

  String _deployStatusLabel(String? status) {
    switch (status) {
      case 'deployed': return '已部署';
      case 'deploying': return '部署中';
      case 'failed': return '部署失败';
      case 'pending': return '待部署';
      default: return '待部署';
    }
  }

  Color _deployStatusColor(String? status) {
    switch (status) {
      case 'deployed': return AppColors.success;
      case 'deploying': return AppColors.warning;
      case 'failed': return AppColors.error;
      case 'pending': return Colors.orange;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 标题
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.rocket_launch, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('一键部署', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('选择租户和服务器，一键完成企业IM服务部署', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
            ]),
            const SizedBox(height: 28),

            // 步骤指示器
            _buildStepIndicator(),
            const SizedBox(height: 28),

            // 步骤内容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: _buildStepContent(),
            ),

            // 已部署租户列表
            const SizedBox(height: 28),
            _buildDeployedList(),
          ]),
        );
  }

  Widget _buildStepIndicator() {
    final steps = ['选择租户', '选择服务器', '确认部署'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isActive = index <= _currentStep;
          final isCurrent = index == _currentStep;
          final isDone = index < _currentStep;
          return Expanded(child: Row(children: [
            if (index > 0) Expanded(child: Container(height: 2, color: isActive ? AppColors.primary : Colors.grey.shade200)),
            Column(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.success : (isCurrent ? AppColors.primary : Colors.grey.shade200),
                  shape: BoxShape.circle,
                  boxShadow: isCurrent ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8)] : null,
                ),
                child: Center(child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : Text('${index + 1}', style: TextStyle(color: isCurrent ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600))),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, color: isActive ? AppColors.primary : AppColors.textSecondary, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal)),
            ]),
            if (index < steps.length - 1) Expanded(child: Container(height: 2, color: index < _currentStep ? AppColors.primary : Colors.grey.shade200)),
          ]));
        }).toList(),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return const SizedBox();
    }
  }

  // 步骤1：选择租户
  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('步骤 1：选择要部署的租户', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('选择一个待部署的租户，系统将为其自动部署企业IM服务', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 20),
      if (_undeployedTenants.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(Icons.check_circle_outline, size: 56, color: AppColors.success.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('所有租户已部署完成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('如需部署新租户，请先在租户管理中添加', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        )
      else
        ..._undeployedTenants.map((t) {
          final isSelected = _selectedTenantId == t['id'].toString();
          final deployStatus = t['deploy_status']?.toString() ?? 'pending';
          return GestureDetector(
            onTap: () => setState(() { _selectedTenantId = t['id'].toString(); _selectedTenant = t; }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: isSelected ? 2 : 1),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.business, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _deployStatusColor(deployStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(_deployStatusLabel(deployStatus), style: TextStyle(fontSize: 11, color: _deployStatusColor(deployStatus), fontWeight: FontWeight.w500)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('企业ID: ${t['enterprise_id']} | 套餐: ${_planLabel(t['plan'] ?? 'basic')} | 最大用户: ${t['max_users'] ?? 100}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
              ]),
            ),
          );
        }),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        ElevatedButton.icon(
          onPressed: _selectedTenantId != null ? () => setState(() => _currentStep = 1) : null,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('下一步：选择服务器'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    ]);
  }

  // 步骤2：选择服务器
  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('步骤 2：选择目标服务器', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('选择一台服务器用于部署企业IM服务（已分配的服务器将覆盖部署）', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 20),
      if (_availableServers.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Icon(Icons.dns_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('暂无服务器', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('请先在服务器管理中添加服务器', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        )
      else
        ..._availableServers.map((s) {
          final isSelected = _selectedServerId == s['id'].toString();
          final isAvailable = s['is_available'] == true;
          final assignedTenant = s['assigned_tenant']?.toString() ?? '';
          return GestureDetector(
            onTap: () => setState(() { _selectedServerId = s['id'].toString(); _selectedServer = s; }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: isSelected ? 2 : 1),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.dns, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAvailable ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isAvailable ? '可用' : '已分配',
                        style: TextStyle(fontSize: 11, color: isAvailable ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('IP: ${s['ip_address']} | 端口: ${s['api_port'] ?? 4001}${assignedTenant.isNotEmpty ? ' | 当前租户: $assignedTenant' : ''}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
              ]),
            ),
          );
        }),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        OutlinedButton.icon(
          onPressed: () => setState(() => _currentStep = 0),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('上一步'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
        ElevatedButton.icon(
          onPressed: _selectedServerId != null ? () => setState(() => _currentStep = 2) : null,
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('下一步：确认部署'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    ]);
  }

  // 步骤3：确认部署
  Widget _buildStep3() {
    final serverAssigned = _selectedServer?['assigned_tenant']?.toString() ?? '';
    final isServerAssigned = serverAssigned.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('步骤 3：确认部署信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('请确认以下部署信息无误后，点击开始部署', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 20),

      // 警告：服务器已分配
      if (isServerAssigned) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.warning.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(child: Text('该服务器已分配给 $serverAssigned，部署将覆盖原有服务', style: const TextStyle(fontSize: 13, color: AppColors.warning))),
          ]),
        ),
      ],

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          _buildInfoRow(Icons.business, '租户名称', _selectedTenant?['name'] ?? ''),
          const Divider(height: 20),
          _buildInfoRow(Icons.badge, '企业ID', _selectedTenant?['enterprise_id'] ?? ''),
          const Divider(height: 20),
          _buildInfoRow(Icons.card_membership, '套餐', _planLabel(_selectedTenant?['plan'] ?? '')),
          const Divider(height: 20),
          _buildInfoRow(Icons.people, '最大用户数', '${_selectedTenant?['max_users'] ?? 100}'),
          const Divider(height: 20),
          _buildInfoRow(Icons.dns, '目标服务器', '${_selectedServer?['name'] ?? ''} (${_selectedServer?['ip_address'] ?? ''})'),
          const Divider(height: 20),
          _buildInfoRow(Icons.settings_ethernet, 'API端口', '${_selectedServer?['api_port'] ?? 4001}'),
          const Divider(height: 20),
          _buildInfoRow(Icons.inventory_2, '部署内容', 'Node.js + SQLite + 企业后端 + 管理后台'),
        ]),
      ),

      // 部署日志
      if (_isDeploying) ...[
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _deployProgress, minHeight: 10, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(_deployProgress >= 1.0 ? AppColors.success : AppColors.primary)),
          )),
          const SizedBox(width: 12),
          Text('${(_deployProgress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.w600, color: _deployProgress >= 1.0 ? AppColors.success : AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 260,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
          child: ListView(
            children: _deployLogs.map((log) {
              Color logColor = const Color(0xFF4EC9B0);
              if (log.contains('成功') || log.contains('完成') || log.contains('通过')) logColor = const Color(0xFF6A9955);
              if (log.contains('失败') || log.contains('错误')) logColor = const Color(0xFFCE9178);
              if (log.startsWith('>') || log.startsWith('  ')) logColor = const Color(0xFF9CDCFE);
              if (log.startsWith('===')) logColor = const Color(0xFFDCDCAA);
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(log, style: TextStyle(color: logColor, fontSize: 12, fontFamily: 'monospace', height: 1.6)),
              );
            }).toList(),
          ),
        ),
      ],

      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (!_isDeploying) OutlinedButton.icon(
          onPressed: () => setState(() => _currentStep = 1),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('上一步'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
        if (!_isDeploying) ElevatedButton.icon(
          onPressed: _startDeploy,
          icon: const Icon(Icons.rocket_launch, size: 18),
          label: const Text('开始部署'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_isDeploying && _deployProgress >= 1.0) ElevatedButton.icon(
          onPressed: () {
            setState(() { _currentStep = 0; _isDeploying = false; _deployProgress = 0; _deployLogs.clear(); _selectedTenantId = null; _selectedServerId = null; _selectedTenant = null; _selectedServer = null; });
            _loadData();
          },
          icon: const Icon(Icons.check, size: 18),
          label: const Text('完成'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 10),
      SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
    ]);
  }

  // 已部署租户列表
  Widget _buildDeployedList() {
    final deployed = _allTenants.where((t) => t['deploy_status'] == 'deployed').toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.history, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('已部署的租户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${deployed.length} 个', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ]),
        const SizedBox(height: 16),
        if (deployed.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Icon(Icons.cloud_off, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('暂无已部署的租户', style: TextStyle(color: AppColors.textSecondary)),
            ]),
          )
        else
          ...deployed.map((t) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text('企业ID: ${t['enterprise_id']} | 服务器: ${t['server_ip'] ?? '未知'} | API: ${t['api_url'] ?? ''} | 套餐: ${_planLabel(t['plan'] ?? '')}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: t['status'] == 'active' ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(t['status'] == 'active' ? '运行中' : '已停用', style: TextStyle(color: t['status'] == 'active' ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _confirmUndeploy(t),
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('一键清除'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          )),
      ]),
    );
  }

  void _confirmUndeploy(Map<String, dynamic> tenant) {
    final name = tenant['name'] ?? '';
    final eid = tenant['enterprise_id'] ?? '';
    final serverIp = tenant['server_ip'] ?? '未知';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
          const SizedBox(width: 8),
          const Text('确认一键清除'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('确定要清除以下企业的部署吗？', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.error.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('企业名称: $name', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('企业ID: $eid', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text('服务器: $serverIp', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('此操作将停止服务器上的企业服务并删除部署文件，服务器将被释放为可用状态，可重新用于部署其他企业。',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade800))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _doUndeploy(tenant); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  void _doUndeploy(Map<String, dynamic> tenant) async {
    final tenantId = tenant['id'].toString();
    final tenantName = tenant['name'] ?? '';
    final eid = tenant['enterprise_id'] ?? '';

    // 显示清除进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text('正在清除 $tenantName...'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('正在连接服务器并清除部署文件，请稍候...'),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ]),
        );
      }),
    );

    final res = await ApiService.saasUndeploy(tenantId);

    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭进度对话框

    if (res.isSuccess || res.code == 200) {
      // 显示清除日志
      final logs = res.data?['log'];
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 8),
            const Text('清除完成'),
          ]),
          content: SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$tenantName ($eid) 已成功清除', style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(res.message, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              if (logs is List) ...[
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      logs.join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent, height: 1.5),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
          ],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$tenantName 清除成功，服务器已释放'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // 刷新数据
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清除失败: ${res.message}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _startDeploy() async {
    if (_selectedTenantId == null || _selectedServerId == null) return;
    setState(() { _isDeploying = true; _deployProgress = 0; _deployLogs.clear(); });

    final tenantName = _selectedTenant?['name'] ?? '';
    final enterpriseId = _selectedTenant?['enterprise_id'] ?? '';

    setState(() {
      _deployLogs.add('=== 开始部署 $tenantName ($enterpriseId) ===');
      _deployLogs.add('正在连接服务器并执行部署，请稍候...');
      _deployProgress = 0.1;
    });

    // 调用后端真实SSH部署API - 使用更长的超时时间
    final res = await ApiService.saasDeploy(_selectedTenantId!, {'server_id': _selectedServerId});

    if (!mounted) return;

    if (res.isSuccess) {
      // 显示后端返回的真实部署日志
      final serverLogs = res.data?['log'];
      if (serverLogs is List) {
        for (int i = 0; i < serverLogs.length; i++) {
          await Future.delayed(const Duration(milliseconds: 150));
          if (!mounted) return;
          setState(() {
            _deployLogs.add(serverLogs[i].toString());
            _deployProgress = 0.1 + 0.9 * (i + 1) / serverLogs.length;
          });
        }
      }

      final apiUrl = res.data?['api_url'] ?? '';
      final adminUrl = res.data?['admin_url'] ?? '';
      setState(() {
        _deployLogs.add('');
        _deployLogs.add('=== 部署完成! ===');
        _deployLogs.add('  企业名称: $tenantName');
        _deployLogs.add('  企业ID: $enterpriseId');
        _deployLogs.add('  API地址: $apiUrl');
        _deployLogs.add('  管理后台: $adminUrl');
        _deployLogs.add('  默认管理员: admin / 123456');
        _deployLogs.add('');
        _deployLogs.add('  用户可通过公用前端输入企业ID "$enterpriseId" 开始使用');
        _deployProgress = 1.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$tenantName 部署成功!'),
          ]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // 刷新数据
      _loadData();
    } else {
      // 显示失败日志
      final serverLogs = res.data?['log'];
      if (serverLogs is List) {
        for (final line in serverLogs) {
          setState(() { _deployLogs.add(line.toString()); });
        }
      }
      setState(() {
        _deployLogs.add('');
        _deployLogs.add('部署失败: ${res.message}');
        _deployLogs.add('请检查服务器SSH连接信息是否正确（IP、端口、用户名、密码）');
        _deployProgress = 1.0;
      });
    }
  }
}
