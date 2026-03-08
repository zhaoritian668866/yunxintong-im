import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'services/api_service.dart';
import 'modules/auth/views/enterprise_id_page.dart';
import 'modules/auth/views/login_page.dart';
import 'modules/im/views/im_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
  runApp(const YunXinTongApp());
}

class YunXinTongApp extends StatelessWidget {
  const YunXinTongApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 根据已保存的session状态决定初始路由
    String initialRoute = '/';
    if (ApiService.userToken.isNotEmpty && ApiService.enterpriseId.isNotEmpty) {
      initialRoute = '/im';
    } else if (ApiService.enterpriseId.isNotEmpty) {
      initialRoute = '/user-login';
    }

    return MaterialApp(
      title: '云信通',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('zh', 'CN'),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const EnterpriseIdPage(),
        '/user-login': (context) => const LoginPage(),
        '/im': (context) => const ImHomePage(),
      },
    );
  }
}
