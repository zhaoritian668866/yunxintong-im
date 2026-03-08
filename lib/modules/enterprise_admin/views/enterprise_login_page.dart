import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class EnterpriseLoginPage extends StatefulWidget {
  const EnterpriseLoginPage({super.key});

  @override
  State<EnterpriseLoginPage> createState() => _EnterpriseLoginPageState();
}

class _EnterpriseLoginPageState extends State<EnterpriseLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMsg;

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = '请输入用户名和密码');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    final res = await ApiService.adminLogin(username, password);
    setState(() => _isLoading = false);
    if (res.isSuccess && res.data != null) {
      ApiService.setAdminToken(res.data['token']);
      await ApiService.saveSession();
      if (mounted) Navigator.pushReplacementNamed(context, '/enterprise-admin');
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.green.shade700, Colors.green.shade400]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text('企业管理后台', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    ApiService.enterpriseName.isNotEmpty ? ApiService.enterpriseName : '企业管理',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: '管理员账号',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          if (_errorMsg != null) ...[
                            const SizedBox(height: 12),
                            Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登录', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回首页', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _usernameController.dispose(); _passwordController.dispose(); super.dispose(); }
}
