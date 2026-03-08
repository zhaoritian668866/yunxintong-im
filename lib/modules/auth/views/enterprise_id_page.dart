import 'package:flutter/material.dart';
import 'dart:async';
import '../../../services/api_service.dart';

class EnterpriseIdPage extends StatefulWidget {
  const EnterpriseIdPage({super.key});

  @override
  State<EnterpriseIdPage> createState() => _EnterpriseIdPageState();
}

class _EnterpriseIdPageState extends State<EnterpriseIdPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _verifyEnterprise() async {
    // 强制失焦确保Flutter Web同步输入框值
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    final eid = _controller.text.trim().toUpperCase();
    if (eid.isEmpty) {
      setState(() => _errorMsg = '请输入企业ID');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    final res = await ApiService.resolveEnterprise(eid);
    setState(() => _isLoading = false);
    if (res.isSuccess && res.data != null) {
      // 只设置企业ID，API地址通过代理路径自动计算
      ApiService.enterpriseId = eid;
      ApiService.enterpriseWsUrl = res.data['ws_url'] ?? '';
      ApiService.enterpriseName = res.data['name'] ?? '';
      await ApiService.saveSession();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/user-login');
      }
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade700, Colors.blue.shade400]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.domain_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text('进入企业空间', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('请输入企业ID以连接企业服务器', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('企业ID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('请向您的企业管理员获取企业ID', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _controller,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: '例如: ENT001',
                              prefixIcon: const Icon(Icons.vpn_key_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onSubmitted: (_) => _verifyEnterprise(),
                          ),
                          if (_errorMsg != null) ...[
                            const SizedBox(height: 12),
                            Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyEnterprise,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('验证并进入', style: TextStyle(fontSize: 16)),
                            ),
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
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}
