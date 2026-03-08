import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../app/app_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
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
                  const SizedBox(height: 40),
                  // Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('云信通', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('企业即时通讯平台', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 40),
                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      tabs: const [Tab(text: '登录'), Tab(text: '注册')],
                      onTap: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Form
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _tabController.index == 0 ? _buildLoginForm() : _buildRegisterForm(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            hintText: '请输入手机号/邮箱',
            prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text('忘记密码？', style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              context.read<AppState>().login(_phoneController.text.isEmpty ? '用户' : _phoneController.text);
            },
            child: const Text('登录'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: '请输入昵称',
            prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            hintText: '请输入手机号/邮箱',
            prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '请输入密码（至少6位）',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: '请再次输入密码',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: _agreeTerms,
                onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    children: [
                      TextSpan(text: '我已阅读并同意 '),
                      TextSpan(text: '服务协议', style: TextStyle(color: AppColors.primary)),
                      TextSpan(text: ' 和 '),
                      TextSpan(text: '隐私政策', style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _agreeTerms ? () {
              context.read<AppState>().login(_nameController.text.isEmpty ? '新用户' : _nameController.text);
            } : null,
            child: const Text('注册'),
          ),
        ),
      ],
    );
  }
}
