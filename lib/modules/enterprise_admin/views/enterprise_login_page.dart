import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:async';
import '../../../services/api_service.dart';

class EnterpriseLoginPage extends StatefulWidget {
  const EnterpriseLoginPage({super.key});

  @override
  State<EnterpriseLoginPage> createState() => _EnterpriseLoginPageState();
}

class _EnterpriseLoginPageState extends State<EnterpriseLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMsg;

  Future<void> _login() async {
    // 先强制失焦，确保Flutter同步输入框的值（Flutter Web已知问题）
    FocusScope.of(context).unfocus();
    // 等待一帧让Flutter同步值
    await Future.delayed(const Duration(milliseconds: 100));
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = '请输入用户名和密码');
      return;
    }
    
    setState(() { _isLoading = true; _errorMsg = null; });
    
    try {
      final res = await ApiService.adminLogin(username, password);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (res.isSuccess && res.data != null) {
        ApiService.setAdminToken(res.data['token']);
        await ApiService.saveSession();
        if (mounted) Navigator.pushReplacementNamed(context, '/enterprise-admin');
      } else {
        setState(() => _errorMsg = res.message.isNotEmpty ? res.message : '登录失败，请检查账号密码');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMsg = '网络错误: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
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
                              focusNode: _usernameFocus,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: '管理员账号',
                                hintText: '请输入管理员账号',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                              onChanged: (_) {
                                if (_errorMsg != null) setState(() => _errorMsg = null);
                              },
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: '密码',
                                hintText: '请输入密码',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                              onChanged: (_) {
                                if (_errorMsg != null) setState(() => _errorMsg = null);
                              },
                            ),
                            if (_errorMsg != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 13), textAlign: TextAlign.center),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '默认账号: admin / 123456',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}
