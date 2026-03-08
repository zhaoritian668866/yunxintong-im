import 'package:flutter/material.dart';
import '../../../widgets/admin_layout.dart';
import '../../../services/api_service.dart';
import 'enterprise_dashboard_page.dart';
import 'enterprise_employee_page.dart';
import 'enterprise_department_page.dart';
import 'enterprise_settings_page.dart';
import 'enterprise_chat_records_page.dart';
import 'enterprise_groups_page.dart';

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
    AdminMenuItem(icon: Icons.chat_outlined, label: '聊天记录', route: 'chat_records'),
    AdminMenuItem(icon: Icons.group_outlined, label: '群组管理', route: 'groups'),
    AdminMenuItem(icon: Icons.settings_outlined, label: '系统设置', route: 'settings'),
  ];

  final _pages = const [
    EnterpriseDashboardPage(),
    EnterpriseEmployeePage(),
    EnterpriseDepartmentPage(),
    EnterpriseChatRecordsPage(),
    EnterpriseGroupsPage(),
    EnterpriseSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: '企业管理后台',
      subtitle: '即时通讯管理',
      menuItems: _menuItems,
      selectedIndex: _selectedIndex,
      onMenuSelected: (i) => setState(() => _selectedIndex = i),
      onLogout: () {
        ApiService.clearAdminSession();
        Navigator.of(context).pushNamedAndRemoveUntil('/enterprise/login', (route) => false);
      },
      body: _pages[_selectedIndex],
    );
  }
}
