import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../app/app_state.dart';

/// 角色切换浮动按钮 - 用于开发调试，方便在三个模块间切换
class RoleSwitcherFab extends StatelessWidget {
  const RoleSwitcherFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      backgroundColor: AppColors.sidebarBg,
      onPressed: () => _showRoleSwitcher(context),
      child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
    );
  }

  void _showRoleSwitcher(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('切换角色（开发调试）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chat, color: AppColors.primary, size: 20),
              ),
              title: const Text('普通用户（IM聊天）'),
              subtitle: const Text('公用前端 - 消息/通讯录/工作台/我的'),
              selected: appState.currentRole == AppRole.user,
              onTap: () {
                appState.switchRole(AppRole.user);
                if (appState.enterpriseId.isEmpty) {
                  appState.setEnterprise('ENT-001', '创新科技有限公司');
                }
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.admin_panel_settings, color: AppColors.warning, size: 20),
              ),
              title: const Text('SaaS 总管理员'),
              subtitle: const Text('SaaS总后台 - 租户/服务器/部署管理'),
              selected: appState.currentRole == AppRole.saasAdmin,
              onTap: () {
                appState.switchRole(AppRole.saasAdmin);
                Navigator.pop(ctx);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business, color: AppColors.success, size: 20),
              ),
              title: const Text('企业管理员'),
              subtitle: const Text('企业后台 - 员工/部门/权限/设置'),
              selected: appState.currentRole == AppRole.enterpriseAdmin,
              onTap: () {
                appState.switchRole(AppRole.enterpriseAdmin);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
