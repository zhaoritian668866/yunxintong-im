import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final res = await ApiService.userProfile();
    if (mounted) {
      setState(() { _loading = false; if (res.isSuccess && res.data != null) _profile = res.data; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const SizedBox(height: 16),
                // 用户信息卡片
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    CircleAvatar(radius: 32, backgroundColor: AppColors.primary,
                      child: Text((_profile?['nickname'] ?? '?')[0], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_profile?['nickname'] ?? '未知', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(_profile?['position'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      if (_profile?['department_name'] != null) ...[
                        const SizedBox(height: 2),
                        Text(_profile!['department_name'], style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                      ],
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
                _buildSettingsGroup([
                  _SettingsItem(icon: Icons.person_outline, title: '个人信息', color: AppColors.primary, onTap: _editProfile),
                  _SettingsItem(icon: Icons.lock_outline, title: '修改密码', color: AppColors.warning, onTap: _changePassword),
                  _SettingsItem(icon: Icons.notifications_outlined, title: '消息通知', color: AppColors.info, onTap: _showNotificationSettings),
                ]),
                const SizedBox(height: 16),
                _buildSettingsGroup([
                  _SettingsItem(icon: Icons.info_outline, title: '关于云信通', color: AppColors.primary, onTap: _showAbout),
                ]),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 48, child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                )),
                const SizedBox(height: 32),
              ]),
            ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Column(children: [
          ListTile(
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, color: item.color, size: 20)),
            title: Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            subtitle: item.subtitle != null ? Text(item.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            onTap: item.onTap ?? () {},
          ),
          if (index < items.length - 1) const Divider(height: 0.5, indent: 56, endIndent: 16),
        ]);
      }).toList()),
    );
  }

  void _editProfile() {
    final nickCtrl = TextEditingController(text: _profile?['nickname'] ?? '');
    final phoneCtrl = TextEditingController(text: _profile?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: _profile?['email'] ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('编辑个人信息'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nickCtrl, decoration: InputDecoration(labelText: '昵称', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: '手机号', prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: emailCtrl, decoration: InputDecoration(labelText: '邮箱', prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          final res = await ApiService.updateProfile({'nickname': nickCtrl.text, 'phone': phoneCtrl.text, 'email': emailCtrl.text});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.isSuccess ? '保存成功' : res.message), behavior: SnackBarBehavior.floating));
            if (res.isSuccess) _loadProfile();
          }
        }, child: const Text('保存')),
      ],
    ));
  }

  void _changePassword() {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('修改密码'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: oldPwdCtrl, obscureText: true, decoration: InputDecoration(labelText: '当前密码', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: newPwdCtrl, obscureText: true, decoration: InputDecoration(labelText: '新密码', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: confirmPwdCtrl, obscureText: true, decoration: InputDecoration(labelText: '确认新密码', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (newPwdCtrl.text != confirmPwdCtrl.text) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次输入的密码不一致'), behavior: SnackBarBehavior.floating));
            return;
          }
          if (oldPwdCtrl.text.isEmpty || newPwdCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写所有字段'), behavior: SnackBarBehavior.floating));
            return;
          }
          if (newPwdCtrl.text.length < 6) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新密码长度不能少于6位'), behavior: SnackBarBehavior.floating));
            return;
          }
          Navigator.pop(ctx);
          final res = await ApiService.changePassword(oldPwdCtrl.text, newPwdCtrl.text);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.isSuccess ? '密码修改成功' : res.message), behavior: SnackBarBehavior.floating));
        }, child: const Text('确认修改')),
      ],
    ));
  }

  void _showNotificationSettings() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('消息通知设置'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(title: const Text('新消息通知'), value: true, onChanged: (v) {}),
        SwitchListTile(title: const Text('声音提醒'), value: true, onChanged: (v) {}),
        SwitchListTile(title: const Text('振动提醒'), value: true, onChanged: (v) {}),
        SwitchListTile(title: const Text('消息预览'), value: true, onChanged: (v) {}),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
    ));
  }

  void _showAbout() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Container(width: 64, height: 64, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.chat_bubble, color: Colors.white, size: 32)),
        const SizedBox(height: 16),
        const Text('云信通', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('多租户企业即时通讯平台', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        const Text('v1.0.0', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
    ));
  }

  void _logout() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('退出登录'),
      content: const Text('确定要退出登录吗？'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          await ApiService.clearUserSession();
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }, child: const Text('确定', style: TextStyle(color: AppColors.error))),
      ],
    ));
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingsItem({required this.icon, required this.title, required this.color, this.subtitle, this.onTap});
}
