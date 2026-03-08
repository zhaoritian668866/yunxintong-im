import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMsg = '请输入用户名和密码');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    final res = await ApiService.userLogin(username, password);
    setState(() => _isLoading = false);
    if (res.isSuccess && res.data != null) {
      ApiService.setUserToken(res.data['token']);
      await ApiService.saveSession();
      if (mounted) Navigator.pushReplacementNamed(context, '/im');
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    final nickname = _nicknameController.text.trim();
    final phone = _phoneController.text.trim();
    if (username.isEmpty || password.isEmpty) { setState(() => _errorMsg = '请输入用户名和密码'); return; }
    if (password.length < 6) { setState(() => _errorMsg = '密码至少6位'); return; }
    if (password != confirm) { setState(() => _errorMsg = '两次密码不一致'); return; }
    if (!_agreeTerms) { setState(() => _errorMsg = '请先同意服务协议'); return; }

    setState(() { _isLoading = true; _errorMsg = null; });
    final res = await ApiService.userRegister(username, password, nickname: nickname.isEmpty ? null : nickname, phone: phone.isEmpty ? null : phone);
    setState(() => _isLoading = false);
    if (res.isSuccess && res.data != null) {
      if (res.data['status'] == 'pending') {
        setState(() => _errorMsg = '注册成功，等待管理员审批');
        _tabController.animateTo(0);
      } else if (res.data['token'] != null) {
        ApiService.setUserToken(res.data['token']);
        await ApiService.saveSession();
        if (mounted) Navigator.pushReplacementNamed(context, '/im');
      }
    } else {
      setState(() => _errorMsg = res.message);
    }
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
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(ApiService.enterpriseName.isNotEmpty ? ApiService.enterpriseName : '云信通', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('企业即时通讯平台', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      tabs: const [Tab(text: '登录'), Tab(text: '注册')],
                      onTap: (_) => setState(() => _errorMsg = null),
                    ),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 32),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _tabController.index == 0 ? _buildLoginForm() : _buildRegisterForm(),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      ApiService.clearUserSession();
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    child: const Text('返回首页', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
          controller: _usernameController,
          decoration: const InputDecoration(hintText: '请输入用户名', prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
            suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
          ),
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登录'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        TextField(controller: _nicknameController, decoration: const InputDecoration(hintText: '请输入昵称', prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary))),
        const SizedBox(height: 16),
        TextField(controller: _usernameController, decoration: const InputDecoration(hintText: '请输入用户名（登录用）', prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary))),
        const SizedBox(height: 16),
        TextField(controller: _phoneController, decoration: const InputDecoration(hintText: '手机号（选填）', prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textSecondary)), keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController, obscureText: _obscurePassword,
          decoration: InputDecoration(hintText: '请输入密码（至少6位）', prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary), onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController, obscureText: _obscureConfirm,
          decoration: InputDecoration(hintText: '请再次输入密码', prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary), suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(width: 24, height: 24, child: Checkbox(value: _agreeTerms, onChanged: (v) => setState(() => _agreeTerms = v ?? false), activeColor: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(onTap: () => setState(() => _agreeTerms = !_agreeTerms), child: RichText(text: const TextSpan(style: TextStyle(fontSize: 13, color: AppColors.textSecondary), children: [TextSpan(text: '我已阅读并同意 '), TextSpan(text: '服务协议', style: TextStyle(color: AppColors.primary)), TextSpan(text: ' 和 '), TextSpan(text: '隐私政策', style: TextStyle(color: AppColors.primary))])))),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _register,
            child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('注册'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() { _tabController.dispose(); _usernameController.dispose(); _passwordController.dispose(); _confirmPasswordController.dispose(); _nicknameController.dispose(); _phoneController.dispose(); super.dispose(); }
}
