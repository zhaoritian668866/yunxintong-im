import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'app/app_state.dart';
import 'services/api_service.dart';
import 'modules/enterprise_admin/views/enterprise_login_page.dart';
import 'modules/enterprise_admin/views/enterprise_admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
  // 企业管理后台部署在企业服务器上，API同域访问（直连模式）
  if (kIsWeb) {
    ApiService.enterpriseDirectUrl = Uri.base.origin + '/api';
  } else {
    ApiService.enterpriseDirectUrl = 'http://localhost:4001/api';
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const EnterpriseApp(),
    ),
  );
}

class EnterpriseApp extends StatelessWidget {
  const EnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '云信通 - 企业管理后台',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('zh', 'CN'),
      initialRoute: '/',
      routes: {
        '/': (context) => const EnterpriseLoginPage(),
        '/enterprise-login': (context) => const EnterpriseLoginPage(),
        '/enterprise/login': (context) => const EnterpriseLoginPage(),
        '/enterprise-admin': (context) => const EnterpriseAdminPage(),
      },
    );
  }
}
