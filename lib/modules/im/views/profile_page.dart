import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../app/app_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
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
                      appState.userName.isNotEmpty ? appState.userName[0] : '用',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.userName.isEmpty ? '张伟' : appState.userName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text('研发部 | 高级工程师', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          appState.enterpriseName.isEmpty ? '创新科技有限公司' : appState.enterpriseName,
                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 设置项 - 第一组
            _buildSettingsGroup([
              _SettingsItem(icon: Icons.shield_outlined, title: '账号与安全', color: AppColors.primary),
              _SettingsItem(icon: Icons.notifications_outlined, title: '消息通知', color: AppColors.warning),
              _SettingsItem(icon: Icons.settings_outlined, title: '通用设置', color: AppColors.textSecondary),
            ]),
            const SizedBox(height: 16),
            // 设置项 - 第二组
            _buildSettingsGroup([
              _SettingsItem(icon: Icons.info_outline, title: '关于云信通', color: AppColors.primary),
              _SettingsItem(icon: Icons.headset_mic_outlined, title: '联系客服购买', color: AppColors.success, isHighlight: true),
            ]),
            const SizedBox(height: 24),
            // 退出登录
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('退出登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
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
          return Column(
            children: [
              ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: item.isHighlight ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                onTap: () {},
              ),
              if (index < items.length - 1)
                const Divider(height: 0.5, indent: 56, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppState>().logout();
            },
            child: const Text('确定', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final Color color;
  final bool isHighlight;
  const _SettingsItem({required this.icon, required this.title, required this.color, this.isHighlight = false});
}
