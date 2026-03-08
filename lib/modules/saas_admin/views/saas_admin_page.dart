import 'package:flutter/material.dart';
import '../../../widgets/admin_layout.dart';
import '../../../services/api_service.dart';
import 'saas_dashboard_page.dart';
import 'saas_tenant_page.dart';
import 'saas_server_page.dart';
import 'saas_deploy_page.dart';

class SaasAdminPage extends StatefulWidget {
  const SaasAdminPage({super.key});

  @override
  State<SaasAdminPage> createState() => _SaasAdminPageState();
}

class _SaasAdminPageState extends State<SaasAdminPage> {
  int _selectedIndex = 0;

  static const _menuItems = [
    AdminMenuItem(icon: Icons.dashboard_outlined, label: '仪表盘', route: 'dashboard'),
    AdminMenuItem(icon: Icons.business_outlined, label: '租户管理', route: 'tenants'),
    AdminMenuItem(icon: Icons.dns_outlined, label: '服务器管理', route: 'servers'),
    AdminMenuItem(icon: Icons.rocket_launch_outlined, label: '一键部署', route: 'deploy'),
    AdminMenuItem(icon: Icons.receipt_long_outlined, label: '订单管理', route: 'orders'),
    AdminMenuItem(icon: Icons.settings_outlined, label: '系统设置', route: 'settings'),
  ];

  final _pages = const [
    SaasDashboardPage(),
    SaasTenantPage(),
    SaasServerPage(),
    SaasDeployPage(),
    Center(child: Text('订单管理 - 开发中', style: TextStyle(fontSize: 16, color: Colors.grey))),
    Center(child: Text('系统设置 - 开发中', style: TextStyle(fontSize: 16, color: Colors.grey))),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: '云信通 SaaS',
      subtitle: '总管理后台',
      menuItems: _menuItems,
      selectedIndex: _selectedIndex,
      onMenuSelected: (i) => setState(() => _selectedIndex = i),
      onLogout: () {
        ApiService.clearToken();
        Navigator.of(context).pushNamedAndRemoveUntil('/saas/login', (route) => false);
      },
      body: _pages[_selectedIndex],
    );
  }
}
