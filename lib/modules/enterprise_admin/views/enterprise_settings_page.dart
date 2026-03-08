import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class EnterpriseSettingsPage extends StatefulWidget {
  const EnterpriseSettingsPage({super.key});

  @override
  State<EnterpriseSettingsPage> createState() => _EnterpriseSettingsPageState();
}

class _EnterpriseSettingsPageState extends State<EnterpriseSettingsPage> {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本设置
          _buildSection('基本设置', [
            _buildSwitchTile('允许自主注册', '员工可通过企业ID自行注册账号', _allowRegister, (v) => setState(() => _allowRegister = v)),
            _buildSwitchTile('注册需审批', '新注册用户需管理员审批后方可使用', _requireApproval, (v) => setState(() => _requireApproval = v)),
          ]),
          const SizedBox(height: 20),
          // 功能设置
          _buildSection('功能设置', [
            _buildSwitchTile('文件共享', '允许用户在聊天中发送文件', _enableFileShare, (v) => setState(() => _enableFileShare = v)),
            _buildSwitchTile('语音通话', '允许用户发起语音通话', _enableVoiceCall, (v) => setState(() => _enableVoiceCall = v)),
            _buildSwitchTile('视频通话', '允许用户发起视频通话', _enableVideoCall, (v) => setState(() => _enableVideoCall = v)),
            _buildSwitchTile('已读回执', '显示消息已读状态', _enableReadReceipt, (v) => setState(() => _enableReadReceipt = v)),
            _buildSwitchTile('消息撤回', '允许用户撤回已发送消息', _enableMsgRecall, (v) => setState(() => _enableMsgRecall = v)),
          ]),
          const SizedBox(height: 20),
          // 限制设置
          _buildSection('限制设置', [
            _buildSliderTile('消息撤回时限', '$_recallTimeout 分钟内可撤回', _recallTimeout.toDouble(), 1, 10, (v) => setState(() => _recallTimeout = v.toInt())),
            _buildSliderTile('文件大小上限', '最大 $_maxFileSize MB', _maxFileSize.toDouble(), 10, 500, (v) => setState(() => _maxFileSize = v.toInt())),
          ]),
          const SizedBox(height: 24),
          // 保存按钮
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('设置已保存'), behavior: SnackBarBehavior.floating),
                );
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('保存设置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildSliderTile(String title, String subtitle, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
