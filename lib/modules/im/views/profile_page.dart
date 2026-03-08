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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final res = await ApiService.userProfile();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) _profile = res.data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 16),
                  // 用户信息卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (_profile?['nickname'] ?? '?')[0],
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_profile?['nickname'] ?? '未知', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Text(_profile?['position'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text('企业: ${ApiService.enterpriseName}', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.qr_code, color: AppColors.textSecondary), onPressed: () {}),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 设置项 - 第一组
                  _buildSettingsGroup([
                    _SettingsItem(icon: Icons.person_outline, title: '个人信息', color: AppColors.primary, onTap: _editProfile),
                    _SettingsItem(icon: Icons.shield_outlined, title: '账号与安全', color: AppColors.primary),
                    _SettingsItem(icon: Icons.notifications_outlined, title: '消息通知', color: AppColors.warning),
                    _SettingsItem(icon: Icons.settings_outlined, title: '通用设置', color: AppColors.textSecondary),
                  ]),
                  const SizedBox(height: 16),
                  _buildSettingsGroup([
                    _SettingsItem(icon: Icons.storage_outlined, title: '数据与存储', color: AppColors.info),
                    _SettingsItem(icon: Icons.language, title: '语言', color: AppColors.success),
                    _SettingsItem(icon: Icons.dark_mode_outlined, title: '深色模式', color: AppColors.textSecondary),
                  ]),
                  const SizedBox(height: 16),
                  _buildSettingsGroup([
                    _SettingsItem(icon: Icons.headset_mic_outlined, title: '联系客服购买', color: AppColors.success, subtitle: '升级服务请联系客服'),
                    _SettingsItem(icon: Icons.info_outline, title: '关于云信通', color: AppColors.primary),
                  ]),
                  const SizedBox(height: 24),
                  // 退出登录
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<_SettingsItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(children: [
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              title: Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              subtitle: item.subtitle != null ? Text(item.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              onTap: item.onTap ?? () {},
            ),
            if (index < items.length - 1) const Divider(height: 0.5, indent: 56, endIndent: 16),
          ]);
        }).toList(),
      ),
    );
  }

  void _editProfile() {
    final nickCtrl = TextEditingController(text: _profile?['nickname'] ?? '');
    final phoneCtrl = TextEditingController(text: _profile?['phone'] ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('编辑个人信息'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nickCtrl, decoration: const InputDecoration(labelText: '昵称', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '手机号', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          await ApiService.updateProfile({'nickname': nickCtrl.text, 'phone': phoneCtrl.text});
          _loadProfile();
        }, child: const Text('保存')),
      ],
    ));
  }

  void _logout() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('退出登录'),
      content: const Text('确定要退出登录吗？'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await ApiService.clearUserSession();
            if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
          child: const Text('确定', style: TextStyle(color: AppColors.error)),
        ),
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
