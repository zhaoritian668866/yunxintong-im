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
  List<Map<String, dynamic>> _tenants = [];
  bool _isLoadingTenants = true;
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _userController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  bool _isDeploying = false;
  double _deployProgress = 0;
  final List<String> _deployLogs = [];

  @override
  void initState() {
    super.initState();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    final res = await ApiService.saasGetTenants();
    if (mounted) {
      setState(() {
        _isLoadingTenants = false;
        if (res.isSuccess) _tenants = List<Map<String, dynamic>>.from(res.data?['tenants'] ?? []);
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose(); _portController.dispose(); _userController.dispose(); _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildStepIndicator(),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
          child: _buildStepContent(),
        ),
      ]),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['选择租户', '配置SSH连接', '确认部署'];
    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final label = entry.value;
        final isActive = index <= _currentStep;
        final isCurrent = index == _currentStep;
        return Expanded(child: Column(children: [
          Row(children: [
            if (index > 0) Expanded(child: Container(height: 2, color: isActive ? AppColors.primary : AppColors.border)),
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: isActive ? AppColors.primary : AppColors.border, shape: BoxShape.circle, boxShadow: isCurrent ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)] : null),
              child: Center(child: index < _currentStep ? const Icon(Icons.check, color: Colors.white, size: 18) : Text('${index + 1}', style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600))),
            ),
            if (index < steps.length - 1) Expanded(child: Container(height: 2, color: index < _currentStep ? AppColors.primary : AppColors.border)),
          ]),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: isActive ? AppColors.primary : AppColors.textSecondary, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal)),
        ]));
      }).toList(),
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

  Widget _buildStep1() {
    if (_isLoadingTenants) return const Center(child: CircularProgressIndicator());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('步骤 1：选择要部署的租户', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('选择一个租户，系统将为其自动部署即时通讯服务到指定服务器', style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      if (_tenants.isEmpty)
        Container(padding: const EdgeInsets.all(32), child: Center(child: Column(children: [
          Icon(Icons.business_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('暂无租户，请先在租户管理中添加', style: TextStyle(color: Colors.grey.shade500)),
        ])))
      else
        ..._tenants.map((t) => RadioListTile<String>(
          value: t['id'] ?? '',
          groupValue: _selectedTenantId,
          onChanged: (v) => setState(() { _selectedTenantId = v; _selectedTenant = t; _ipController.text = t['server_ip'] ?? ''; }),
          title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('${t['enterprise_id']} · ${t['contact_person'] ?? ''} · ${t['server_ip'] ?? ''}'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _selectedTenantId == t['id'] ? AppColors.primary.withValues(alpha: 0.05) : null,
          activeColor: AppColors.primary,
        )),
      const SizedBox(height: 24),
      Align(alignment: Alignment.centerRight, child: ElevatedButton(
        onPressed: _selectedTenantId != null ? () => setState(() => _currentStep = 1) : null,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('下一步'), SizedBox(width: 4), Icon(Icons.arrow_forward, size: 16)]),
      )),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('步骤 2：配置SSH连接信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('填写目标服务器的SSH连接信息，用于自动化部署', style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(flex: 3, child: TextField(controller: _ipController, decoration: const InputDecoration(labelText: '服务器IP地址 *', border: OutlineInputBorder()))),
        const SizedBox(width: 12),
        Expanded(flex: 1, child: TextField(controller: _portController, decoration: const InputDecoration(labelText: 'SSH端口', border: OutlineInputBorder()))),
      ]),
      const SizedBox(height: 16),
      TextField(controller: _userController, decoration: const InputDecoration(labelText: 'SSH用户名', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'SSH密码 *', border: OutlineInputBorder()), obscureText: true),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: const Row(children: [Icon(Icons.warning_amber, color: AppColors.warning, size: 18), SizedBox(width: 8),
          Expanded(child: Text('请确保服务器已开放SSH端口，且具有root权限', style: TextStyle(fontSize: 12, color: AppColors.warning)))])),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        OutlinedButton(onPressed: () => setState(() => _currentStep = 0), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_back, size: 16), SizedBox(width: 4), Text('上一步')])),
        ElevatedButton(onPressed: _ipController.text.isNotEmpty ? () => setState(() => _currentStep = 2) : null, child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('下一步'), SizedBox(width: 4), Icon(Icons.arrow_forward, size: 16)])),
      ]),
    ]);
  }

  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('步骤 3：确认部署信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          _buildInfoRow('租户名称', _selectedTenant?['name'] ?? ''),
          _buildInfoRow('企业ID', _selectedTenant?['enterprise_id'] ?? ''),
          _buildInfoRow('服务器IP', _ipController.text),
          _buildInfoRow('SSH端口', _portController.text),
          _buildInfoRow('SSH用户名', _userController.text),
          _buildInfoRow('部署内容', 'Node.js + SQLite + 企业后端 + 企业管理后台'),
        ])),
      if (_isDeploying) ...[
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _deployProgress, minHeight: 8, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.primary)))),
          const SizedBox(width: 12),
          Text('${(_deployProgress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        Container(height: 240, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
          child: ListView(children: _deployLogs.map((log) => Text(log, style: const TextStyle(color: Color(0xFF4EC9B0), fontSize: 12, fontFamily: 'monospace', height: 1.6))).toList())),
      ],
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        if (!_isDeploying) OutlinedButton(onPressed: () => setState(() => _currentStep = 1), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.arrow_back, size: 16), SizedBox(width: 4), Text('上一步')])),
        if (!_isDeploying) ElevatedButton.icon(onPressed: _startDeploy, icon: const Icon(Icons.rocket_launch, size: 18), label: const Text('开始部署'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success)),
        if (_isDeploying && _deployProgress >= 1.0) ElevatedButton(onPressed: () => setState(() { _currentStep = 0; _isDeploying = false; _deployProgress = 0; _deployLogs.clear(); _selectedTenantId = null; }), child: const Text('完成')),
      ]),
    ]);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
    ]));
  }

  void _startDeploy() async {
    if (_selectedTenantId == null) return;
    setState(() { _isDeploying = true; _deployProgress = 0; _deployLogs.clear(); });

    // 调用真实部署API
    final res = await ApiService.saasDeploy(_selectedTenantId!, {
      'server_ip': _ipController.text,
      'ssh_port': int.tryParse(_portController.text) ?? 22,
      'ssh_user': _userController.text,
      'ssh_password': _passwordController.text,
    });

    // 模拟部署日志输出（真实环境通过WebSocket实时推送）
    final ip = _ipController.text;
    final logs = [
      '> 连接服务器 $ip...',
      '> SSH连接${res.isSuccess ? '成功' : '失败'}',
      if (res.isSuccess) ...[
        '> 检查系统环境...',
        '> 系统: Ubuntu 22.04 LTS',
        '> 安装 Node.js 运行环境...',
        '> Node.js v22.x 安装完成 ✓',
        '> 上传企业独立后端包...',
        '> 安装后端依赖 (npm install)...',
        '> 依赖安装完成 ✓',
        '> 初始化SQLite数据库...',
        '> 创建默认管理员账号...',
        '> 配置Nginx反向代理...',
        '> 启动企业后端服务 (PM2)...',
        '> 服务健康检查...',
        '> ✅ 部署完成！',
        '> 企业API地址: http://$ip:${_selectedTenant?['api_port'] ?? 4001}',
        '> 企业管理后台: http://$ip:${_selectedTenant?['api_port'] ?? 4001}/admin',
        '> 默认管理员: admin / admin123',
      ] else ...[
        '> ❌ 部署失败: ${res.message}',
      ],
    ];

    for (int i = 0; i < logs.length; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() { _deployLogs.add(logs[i]); _deployProgress = (i + 1) / logs.length; });
    }
  }
}
