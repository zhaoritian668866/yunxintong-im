import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'app/app_state.dart';
import 'services/api_service.dart';
import 'modules/saas_admin/views/saas_login_page.dart';
import 'modules/saas_admin/views/saas_admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SaasApp(),
    ),
  );
}

class SaasApp extends StatelessWidget {
  const SaasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '云信通 - SaaS管理后台',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('zh', 'CN'),
      initialRoute: '/',
      routes: {
        '/': (context) => const SaasLoginPage(),
        '/saas-login': (context) => const SaasLoginPage(),
        '/saas/login': (context) => const SaasLoginPage(),
        '/saas-admin': (context) => const SaasAdminPage(),
      },
    );
  }
}
