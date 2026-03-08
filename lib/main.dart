import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'app/app_state.dart';
import 'services/api_service.dart';
import 'modules/auth/views/login_page.dart';
import 'modules/auth/views/enterprise_id_page.dart';
import 'modules/im/views/im_home_page.dart';
import 'modules/saas_admin/views/saas_login_page.dart';
import 'modules/saas_admin/views/saas_admin_page.dart';
import 'modules/enterprise_admin/views/enterprise_login_page.dart';
import 'modules/enterprise_admin/views/enterprise_admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
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
      locale: const Locale('zh', 'CN'),
      initialRoute: '/',
      routes: {
        '/': (context) => const AppEntryPage(),
        '/enterprise-id': (context) => const EnterpriseIdPage(),
        '/user-login': (context) => const LoginPage(),
        '/im': (context) => const ImHomePage(),
        '/saas/login': (context) => const SaasLoginPage(),
        '/saas-login': (context) => const SaasLoginPage(),
        '/saas-admin': (context) => const SaasAdminPage(),
        '/enterprise/login': (context) => const EnterpriseLoginPage(),
        '/enterprise-login': (context) => const EnterpriseLoginPage(),
        '/enterprise-admin': (context) => const EnterpriseAdminPage(),
      },
    );
  }
}

/// 应用入口页 - 选择进入哪个系统
class AppEntryPage extends StatelessWidget {
  const AppEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade700, Colors.blue.shade400],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_rounded, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text('云信通', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('多租户企业即时通讯平台', style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 60),
                  _buildEntryCard(
                    context,
                    icon: Icons.message_rounded,
                    title: '进入通讯',
                    subtitle: '输入企业ID，注册/登录后开始聊天',
                    color: Colors.blue,
                    onTap: () => Navigator.pushNamed(context, '/enterprise-id'),
                  ),
                  const SizedBox(height: 16),
                  _buildEntryCard(
                    context,
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'SaaS管理后台',
                    subtitle: '平台管理员登录，管理租户与部署',
                    color: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, '/saas-login'),
                  ),
                  const SizedBox(height: 16),
                  _buildEntryCard(
                    context,
                    icon: Icons.business_rounded,
                    title: '企业管理后台',
                    subtitle: '企业管理员登录，管理员工与设置',
                    color: Colors.green,
                    onTap: () {
                      if (ApiService.enterpriseApiUrl.isEmpty) {
                        Navigator.pushNamed(context, '/enterprise-id', arguments: 'admin');
                      } else {
                        Navigator.pushNamed(context, '/enterprise-login');
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                  Text('v1.0.0', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
