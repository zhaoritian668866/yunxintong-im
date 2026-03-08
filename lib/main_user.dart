import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'app/app_state.dart';
import 'services/api_service.dart';
import 'modules/auth/views/login_page.dart';
import 'modules/auth/views/enterprise_id_page.dart';
import 'modules/im/views/im_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadSession();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const UserApp(),
    ),
  );
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '云信通',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('zh', 'CN'),
      initialRoute: '/',
      routes: {
        '/': (context) => const EnterpriseIdPage(),
        '/enterprise-id': (context) => const EnterpriseIdPage(),
        '/user-login': (context) => const LoginPage(),
        '/im': (context) => const ImHomePage(),
      },
    );
  }
}
