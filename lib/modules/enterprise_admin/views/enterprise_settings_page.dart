import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../services/api_service.dart';

class EnterpriseSettingsPage extends StatefulWidget {
  const EnterpriseSettingsPage({super.key});

  @override
  State<EnterpriseSettingsPage> createState() => _EnterpriseSettingsPageState();
}

class _EnterpriseSettingsPageState extends State<EnterpriseSettingsPage> {
  bool _isLoading = true;
  bool _allowRegister = true;
  bool _requireApproval = true;
  bool _enableFileShare = true;
  bool _enableVoiceCall = true;
  bool _enableVideoCall = false;
  bool _enableReadReceipt = true;
  bool _enableMsgRecall = true;
  int _recallTimeout = 2;
  int _maxFileSize = 100;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final res = await ApiService.enterpriseGetSettings();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          final s = res.data!;
          _allowRegister = s['allow_register'] == 1;
          _requireApproval = s['require_approval'] == 1;
          _enableFileShare = s['enable_file_share'] == 1;
          _enableVoiceCall = s['enable_voice_call'] == 1;
          _enableVideoCall = s['enable_video_call'] == 1;
          _enableReadReceipt = s['enable_read_receipt'] == 1;
          _enableMsgRecall = s['enable_msg_recall'] == 1;
          _recallTimeout = s['recall_timeout'] ?? 2;
          _maxFileSize = s['max_file_size'] ?? 100;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    final res = await ApiService.enterpriseUpdateSettings({
      'allow_register': _allowRegister ? 1 : 0,
      'require_approval': _requireApproval ? 1 : 0,
      'enable_file_share': _enableFileShare ? 1 : 0,
      'enable_voice_call': _enableVoiceCall ? 1 : 0,
      'enable_video_call': _enableVideoCall ? 1 : 0,
      'enable_read_receipt': _enableReadReceipt ? 1 : 0,
      'enable_msg_recall': _enableMsgRecall ? 1 : 0,
      'recall_timeout': _recallTimeout,
      'max_file_size': _maxFileSize,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.isSuccess ? '设置已保存' : '保存失败: ${res.message}'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSection('基本设置', [
          _buildSwitchTile('允许自主注册', '员工可通过企业ID自行注册账号', _allowRegister, (v) => setState(() => _allowRegister = v)),
          _buildSwitchTile('注册需审批', '新注册用户需管理员审批后方可使用', _requireApproval, (v) => setState(() => _requireApproval = v)),
        ]),
        const SizedBox(height: 20),
        _buildSection('功能设置', [
          _buildSwitchTile('文件共享', '允许用户在聊天中发送文件', _enableFileShare, (v) => setState(() => _enableFileShare = v)),
          _buildSwitchTile('语音通话', '允许用户发起语音通话', _enableVoiceCall, (v) => setState(() => _enableVoiceCall = v)),
          _buildSwitchTile('视频通话', '允许用户发起视频通话', _enableVideoCall, (v) => setState(() => _enableVideoCall = v)),
          _buildSwitchTile('已读回执', '显示消息已读状态', _enableReadReceipt, (v) => setState(() => _enableReadReceipt = v)),
          _buildSwitchTile('消息撤回', '允许用户撤回已发送消息', _enableMsgRecall, (v) => setState(() => _enableMsgRecall = v)),
        ]),
        const SizedBox(height: 20),
        _buildSection('限制设置', [
          _buildSliderTile('消息撤回时限', '$_recallTimeout 分钟内可撤回', _recallTimeout.toDouble(), 1, 10, (v) => setState(() => _recallTimeout = v.toInt())),
          _buildSliderTile('文件大小上限', '最大 $_maxFileSize MB', _maxFileSize.toDouble(), 10, 500, (v) => setState(() => _maxFileSize = v.toInt())),
        ]),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(
          onPressed: _saveSettings, icon: const Icon(Icons.save, size: 18), label: const Text('保存设置'),
        )),
      ]),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        ...children,
      ]),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value, onChanged: onChanged, activeColor: AppColors.primary, contentPadding: const EdgeInsets.symmetric(horizontal: 20));
  }

  Widget _buildSliderTile(String title, String subtitle, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const Spacer(), Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))]),
      Slider(value: value, min: min, max: max, divisions: (max - min).toInt(), onChanged: onChanged, activeColor: AppColors.primary),
    ]));
  }
}
