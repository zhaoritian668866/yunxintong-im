import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class SaasSettingsPage extends StatefulWidget {
  const SaasSettingsPage({super.key});

  @override
  State<SaasSettingsPage> createState() => _SaasSettingsPageState();
}

class _SaasSettingsPageState extends State<SaasSettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _settings = {};

  // 基本设置
  final _platformNameCtrl = TextEditingController();
  final _platformDescCtrl = TextEditingController();
  final _contactEmailCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  // 安全设置
  bool _enableRegistration = true;
  bool _enableEmailVerify = false;
  bool _enableTwoFactor = false;
  int _maxLoginAttempts = 5;
  int _sessionTimeout = 24;

  // 套餐设置
  final _basicPriceCtrl = TextEditingController(text: '299');
  final _proPriceCtrl = TextEditingController(text: '599');
  final _entPriceCtrl = TextEditingController(text: '999');
  final _basicMaxUsersCtrl = TextEditingController(text: '50');
  final _proMaxUsersCtrl = TextEditingController(text: '200');
  final _entMaxUsersCtrl = TextEditingController(text: '1000');

  // 管理员管理
  List<Map<String, dynamic>> _admins = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final res = await ApiService.saasGetSettings();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data is Map) {
          _settings = Map<String, dynamic>.from(res.data);
          _platformNameCtrl.text = _settings['platform_name'] ?? '云信通';
          _platformDescCtrl.text = _settings['platform_desc'] ?? '多租户企业即时通讯平台';
          _contactEmailCtrl.text = _settings['contact_email'] ?? '';
          _contactPhoneCtrl.text = _settings['contact_phone'] ?? '';
          _enableRegistration = _settings['enable_registration'] ?? true;
          _enableEmailVerify = _settings['enable_email_verify'] ?? false;
          _enableTwoFactor = _settings['enable_two_factor'] ?? false;
          _maxLoginAttempts = _settings['max_login_attempts'] ?? 5;
          _sessionTimeout = _settings['session_timeout'] ?? 24;
          _basicPriceCtrl.text = '${_settings['basic_price'] ?? 299}';
          _proPriceCtrl.text = '${_settings['pro_price'] ?? 599}';
          _entPriceCtrl.text = '${_settings['ent_price'] ?? 999}';
          _basicMaxUsersCtrl.text = '${_settings['basic_max_users'] ?? 50}';
          _proMaxUsersCtrl.text = '${_settings['pro_max_users'] ?? 200}';
          _entMaxUsersCtrl.text = '${_settings['ent_max_users'] ?? 1000}';
          if (_settings['admins'] is List) {
            _admins = List<Map<String, dynamic>>.from(_settings['admins']);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _platformNameCtrl.dispose();
    _platformDescCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _basicPriceCtrl.dispose();
    _proPriceCtrl.dispose();
    _entPriceCtrl.dispose();
    _basicMaxUsersCtrl.dispose();
    _proMaxUsersCtrl.dispose();
    _entMaxUsersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(children: [
      Container(
        color: AppColors.cardBg,
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.tune, size: 18), text: '基本设置'),
            Tab(icon: Icon(Icons.security, size: 18), text: '安全设置'),
            Tab(icon: Icon(Icons.card_membership, size: 18), text: '套餐配置'),
            Tab(icon: Icon(Icons.admin_panel_settings, size: 18), text: '管理员'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBasicSettings(),
            _buildSecuritySettings(),
            _buildPlanSettings(),
            _buildAdminManagement(),
          ],
        ),
      ),
    ]);
  }

  Widget _buildBasicSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionCard('平台信息', Icons.info_outline, [
          _buildTextField(_platformNameCtrl, '平台名称', Icons.business),
          const SizedBox(height: 16),
          _buildTextField(_platformDescCtrl, '平台描述', Icons.description, maxLines: 3),
        ]),
        const SizedBox(height: 20),
        _buildSectionCard('联系方式', Icons.contact_mail, [
          _buildTextField(_contactEmailCtrl, '联系邮箱', Icons.email),
          const SizedBox(height: 16),
          _buildTextField(_contactPhoneCtrl, '联系电话', Icons.phone),
        ]),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(
          onPressed: _saveBasicSettings,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存设置'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        )),
      ]),
    );
  }

  Widget _buildSecuritySettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionCard('注册与认证', Icons.verified_user, [
          _buildSwitchTile('允许新用户注册', '开启后租户可以自行注册账号', _enableRegistration, (v) => setState(() => _enableRegistration = v)),
          const Divider(height: 1),
          _buildSwitchTile('邮箱验证', '注册时需要验证邮箱地址', _enableEmailVerify, (v) => setState(() => _enableEmailVerify = v)),
          const Divider(height: 1),
          _buildSwitchTile('双因素认证', '登录时需要额外的验证步骤', _enableTwoFactor, (v) => setState(() => _enableTwoFactor = v)),
        ]),
        const SizedBox(height: 20),
        _buildSectionCard('登录安全', Icons.lock, [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('最大登录尝试次数', style: TextStyle(fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text('超过次数后账号将被临时锁定', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              SizedBox(width: 80, child: DropdownButtonFormField<int>(
                value: _maxLoginAttempts,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: [3, 5, 10].map((v) => DropdownMenuItem(value: v, child: Text('$v次'))).toList(),
                onChanged: (v) => setState(() => _maxLoginAttempts = v!),
              )),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('会话超时时间', style: TextStyle(fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text('超过时间后需要重新登录', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              SizedBox(width: 100, child: DropdownButtonFormField<int>(
                value: _sessionTimeout,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: [1, 6, 12, 24, 72, 168].map((v) => DropdownMenuItem(value: v, child: Text(v < 24 ? '${v}小时' : '${v ~/ 24}天'))).toList(),
                onChanged: (v) => setState(() => _sessionTimeout = v!),
              )),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(
          onPressed: _saveSecuritySettings,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存设置'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        )),
      ]),
    );
  }

  Widget _buildPlanSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 900 ? 3 : 1;
          return GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
            children: [
              _buildPlanCard('基础版', 'basic', AppColors.info, _basicPriceCtrl, _basicMaxUsersCtrl, ['50人以内', '基础IM功能', '5GB存储', '邮件支持']),
              _buildPlanCard('专业版', 'professional', AppColors.primary, _proPriceCtrl, _proMaxUsersCtrl, ['200人以内', '全部IM功能', '50GB存储', '优先支持', '数据导出']),
              _buildPlanCard('企业版', 'enterprise', const Color(0xFF9C27B0), _entPriceCtrl, _entMaxUsersCtrl, ['1000人以内', '全部功能', '500GB存储', '专属客服', '定制开发', 'SLA保障']),
            ],
          );
        }),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(
          onPressed: _savePlanSettings,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存套餐配置'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        )),
      ]),
    );
  }

  Widget _buildPlanCard(String name, String key, Color color, TextEditingController priceCtrl, TextEditingController maxUsersCtrl, List<String> features) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: priceCtrl,
          decoration: InputDecoration(
            labelText: '月价格 (¥)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixText: '¥ ',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: maxUsersCtrl,
          decoration: InputDecoration(
            labelText: '最大用户数',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixText: '人',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        const Text('包含功能:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ...features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(Icons.check_circle, size: 14, color: color),
            const SizedBox(width: 6),
            Text(f, style: const TextStyle(fontSize: 12)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildAdminManagement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ElevatedButton.icon(
            onPressed: _showAddAdminDialog,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('添加管理员'),
          ),
        ]),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: _admins.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.admin_panel_settings_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('暂无管理员数据', style: TextStyle(color: Colors.grey.shade500)),
                  ])),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.background),
                    columns: const [
                      DataColumn(label: Text('用户名', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('昵称', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('角色', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('状态', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('创建时间', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                    rows: _admins.map((a) => DataRow(cells: [
                      DataCell(Text(a['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(a['nickname'] ?? '')),
                      DataCell(_buildRoleBadge(a['role'] ?? '')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (a['status'] == 1 ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(a['status'] == 1 ? '正常' : '禁用', style: TextStyle(fontSize: 12, color: a['status'] == 1 ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600)),
                      )),
                      DataCell(Text(_formatTime(a['created_at'] ?? ''), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary), onPressed: () => _showEditAdminDialog(a), tooltip: '编辑'),
                        if (a['username'] != 'admin')
                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error), onPressed: () => _deleteAdmin(a), tooltip: '删除'),
                      ])),
                    ])).toList(),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isSuperAdmin = role == 'super_admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isSuperAdmin ? const Color(0xFF9C27B0) : AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(isSuperAdmin ? '超级管理员' : '管理员', style: TextStyle(fontSize: 12, color: isSuperAdmin ? const Color(0xFF9C27B0) : AppColors.primary, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
      ]),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    try {
      final dt = DateTime.parse(time);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return time;
    }
  }

  Future<void> _saveBasicSettings() async {
    final res = await ApiService.saasUpdateSettings({
      'platform_name': _platformNameCtrl.text,
      'platform_desc': _platformDescCtrl.text,
      'contact_email': _contactEmailCtrl.text,
      'contact_phone': _contactPhoneCtrl.text,
    });
    _showSaveResult(res.isSuccess);
  }

  Future<void> _saveSecuritySettings() async {
    final res = await ApiService.saasUpdateSettings({
      'enable_registration': _enableRegistration,
      'enable_email_verify': _enableEmailVerify,
      'enable_two_factor': _enableTwoFactor,
      'max_login_attempts': _maxLoginAttempts,
      'session_timeout': _sessionTimeout,
    });
    _showSaveResult(res.isSuccess);
  }

  Future<void> _savePlanSettings() async {
    final res = await ApiService.saasUpdateSettings({
      'basic_price': int.tryParse(_basicPriceCtrl.text) ?? 299,
      'pro_price': int.tryParse(_proPriceCtrl.text) ?? 599,
      'ent_price': int.tryParse(_entPriceCtrl.text) ?? 999,
      'basic_max_users': int.tryParse(_basicMaxUsersCtrl.text) ?? 50,
      'pro_max_users': int.tryParse(_proMaxUsersCtrl.text) ?? 200,
      'ent_max_users': int.tryParse(_entMaxUsersCtrl.text) ?? 1000,
    });
    _showSaveResult(res.isSuccess);
  }

  void _showSaveResult(bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? '设置已保存' : '保存失败'),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  void _showAddAdminDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nicknameCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.person_add, color: AppColors.primary), SizedBox(width: 8), Text('添加管理员')]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: usernameCtrl, decoration: InputDecoration(labelText: '用户名 *', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 12),
        TextField(controller: passwordCtrl, obscureText: true, decoration: InputDecoration(labelText: '密码 *', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 12),
        TextField(controller: nicknameCtrl, decoration: InputDecoration(labelText: '昵称', prefixIcon: const Icon(Icons.badge), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
          Navigator.pop(ctx);
          final res = await ApiService.saasCreateAdmin({'username': usernameCtrl.text, 'password': passwordCtrl.text, 'nickname': nicknameCtrl.text});
          if (res.isSuccess) { _loadSettings(); _showSaveResult(true); }
          else { _showSaveResult(false); }
        }, child: const Text('添加')),
      ],
    ));
  }

  void _showEditAdminDialog(Map<String, dynamic> admin) {
    final nicknameCtrl = TextEditingController(text: admin['nickname']);
    final passwordCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [const Icon(Icons.edit, color: AppColors.primary), const SizedBox(width: 8), Text('编辑管理员 ${admin['username']}')]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nicknameCtrl, decoration: InputDecoration(labelText: '昵称', prefixIcon: const Icon(Icons.badge), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 12),
        TextField(controller: passwordCtrl, obscureText: true, decoration: InputDecoration(labelText: '新密码 (留空不修改)', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          final data = <String, dynamic>{'nickname': nicknameCtrl.text};
          if (passwordCtrl.text.isNotEmpty) data['password'] = passwordCtrl.text;
          final res = await ApiService.saasUpdateAdmin(admin['id'], data);
          if (res.isSuccess) { _loadSettings(); _showSaveResult(true); }
          else { _showSaveResult(false); }
        }, child: const Text('保存')),
      ],
    ));
  }

  void _deleteAdmin(Map<String, dynamic> admin) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.warning, color: AppColors.error), SizedBox(width: 8), Text('删除管理员')]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text('确定要删除管理员 ${admin['username']} 吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () async {
            Navigator.pop(ctx);
            final res = await ApiService.saasDeleteAdmin(admin['id']);
            if (res.isSuccess) { _loadSettings(); _showSaveResult(true); }
            else { _showSaveResult(false); }
          },
          child: const Text('删除'),
        ),
      ],
    ));
  }
}
