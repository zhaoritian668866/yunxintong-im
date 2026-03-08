import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'app/app_state.dart';
import 'modules/auth/views/login_page.dart';
import 'modules/auth/views/enterprise_id_page.dart';
import 'modules/im/views/im_home_page.dart';
import 'modules/saas_admin/views/saas_admin_page.dart';
import 'modules/enterprise_admin/views/enterprise_admin_page.dart';
import 'widgets/role_switcher.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const YunXinTongApp(),
    ),
  );
}

class YunXinTongApp extends StatelessWidget {
  const YunXinTongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '云信通',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppNavigator(),
    );
  }
}

/// 根据应用状态自动导航到正确的页面
class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // 未登录 → 登录页
    if (!appState.isLoggedIn) {
      return const LoginPage();
    }

    // 已登录，构建对应页面并附加角色切换按钮
    Widget page;
    switch (appState.currentRole) {
      case AppRole.saasAdmin:
        page = const SaasAdminPage();
      case AppRole.enterpriseAdmin:
        page = const EnterpriseAdminPage();
      case AppRole.user:
        if (appState.enterpriseId.isEmpty) {
          page = const EnterpriseIdPage();
        } else {
          page = const ImHomePage();
        }
    }

    // 在已登录状态下添加角色切换浮动按钮（开发调试用）
    return Stack(
      children: [
        page,
        const Positioned(
          right: 16,
          bottom: 100,
          child: RoleSwitcherFab(),
        ),
      ],
    );
  }
}
