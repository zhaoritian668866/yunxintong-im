import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/app_state.dart';
import '../../../widgets/admin_layout.dart';
import 'enterprise_dashboard_page.dart';
import 'enterprise_employee_page.dart';
import 'enterprise_department_page.dart';
import 'enterprise_settings_page.dart';

class EnterpriseAdminPage extends StatefulWidget {
  const EnterpriseAdminPage({super.key});

  @override
  State<EnterpriseAdminPage> createState() => _EnterpriseAdminPageState();
}

class _EnterpriseAdminPageState extends State<EnterpriseAdminPage> {
  int _selectedIndex = 0;

  static const _menuItems = [
    AdminMenuItem(icon: Icons.dashboard_outlined, label: '仪表盘', route: 'dashboard'),
    AdminMenuItem(icon: Icons.people_outlined, label: '员工管理', route: 'employees'),
    AdminMenuItem(icon: Icons.account_tree_outlined, label: '部门管理', route: 'departments'),
    AdminMenuItem(icon: Icons.group_outlined, label: '群组管理', route: 'groups'),
    AdminMenuItem(icon: Icons.security_outlined, label: '权限管理', route: 'permissions'),
    AdminMenuItem(icon: Icons.settings_outlined, label: '系统设置', route: 'settings'),
  ];

  final _pages = const [
    EnterpriseDashboardPage(),
    EnterpriseEmployeePage(),
    EnterpriseDepartmentPage(),
    Center(child: Text('群组管理 - 开发中')),
    Center(child: Text('权限管理 - 开发中')),
    EnterpriseSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return AdminLayout(
      title: appState.enterpriseName.isEmpty ? '创新科技有限公司' : appState.enterpriseName,
      subtitle: '企业管理后台',
      menuItems: _menuItems,
      selectedIndex: _selectedIndex,
      onMenuSelected: (i) => setState(() => _selectedIndex = i),
      onLogout: () => context.read<AppState>().logout(),
      body: _pages[_selectedIndex],
    );
  }
}
