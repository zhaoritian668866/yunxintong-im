import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../app/app_state.dart';

class EnterpriseIdPage extends StatefulWidget {
  const EnterpriseIdPage({super.key});

  @override
  State<EnterpriseIdPage> createState() => _EnterpriseIdPageState();
}

class _EnterpriseIdPageState extends State<EnterpriseIdPage> {
  final _enterpriseIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  void _joinEnterprise() async {
    final id = _enterpriseIdController.text.trim();
    if (id.isEmpty) {
      setState(() => _errorText = '请输入企业ID');
      return;
    }
    setState(() { _isLoading = true; _errorText = null; });
    // 模拟网络请求
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.read<AppState>().setEnterprise(id, '创新科技有限公司');
  }

  @override
  void dispose() {
    _enterpriseIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(height: 24),
                  const Text('欢迎回来', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('请输入您的企业ID以进入工作空间', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 40),
                  // Enterprise ID Input
                  TextField(
                    controller: _enterpriseIdController,
                    decoration: InputDecoration(
                      hintText: '例如: COMP-20240001',
                      labelText: '企业ID',
                      prefixIcon: const Icon(Icons.corporate_fare_rounded, color: AppColors.textSecondary),
                      errorText: _errorText,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _joinEnterprise(),
                  ),
                  const SizedBox(height: 12),
                  // Hint text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '企业ID由管理员提供，如有疑问请联系您的企业管理员',
                            style: TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Join Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _joinEnterprise,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('进入工作空间'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Contact support
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.headset_mic_outlined, size: 18),
                    label: const Text('联系客服购买', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 24),
                  // Logout
                  TextButton(
                    onPressed: () => context.read<AppState>().logout(),
                    child: const Text('退出登录', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
