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

  // 基本设置
  bool _allowRegister = true;
  bool _requireApproval = true;

  // 聊天功能开关
  bool _enableVoiceMessage = true;
  bool _enableImageSend = true;
  bool _enableVideoSend = true;
  bool _enableEmoji = true;
  bool _enableVoiceCall = true;
  bool _enableVideoCall = false;
  bool _enableReadReceipt = true;
  bool _enableMsgRecall = true;
  bool _enableFileSend = true;

  // 工作台功能开关
  bool _enableWorkbench = true;
  bool _enableSchedule = true;
  bool _enableTask = true;
  bool _enableCloudDrive = true;
  bool _enableApproval = true;
  bool _enableAttendance = true;
  bool _enableMeetingRoom = true;
  bool _enableAnnouncement = true;
  bool _enableVoting = true;
  bool _enableExpense = true;
  bool _enableCalendar = true;
  bool _enableReport = true;
  bool _enableAnalytics = true;

  // 限制设置
  int _recallTimeout = 2;
  int _maxFileSize = 50;

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
          _allowRegister = (s['allow_group_creation'] ?? 1) == 1;
          _requireApproval = (s['require_approval'] ?? 0) == 1;

          _enableVoiceMessage = (s['enable_voice_message'] ?? 1) == 1;
          _enableImageSend = (s['enable_image_send'] ?? 1) == 1;
          _enableVideoSend = (s['enable_video_send'] ?? 1) == 1;
          _enableEmoji = (s['enable_emoji'] ?? 1) == 1;
          _enableVoiceCall = (s['enable_voice_call'] ?? 1) == 1;
          _enableVideoCall = (s['enable_video_call'] ?? 0) == 1;
          _enableReadReceipt = (s['enable_read_receipt'] ?? 1) == 1;
          _enableMsgRecall = (s['enable_msg_recall'] ?? 1) == 1;
          _enableFileSend = (s['enable_file_send'] ?? 1) == 1;

          _enableWorkbench = (s['enable_workbench'] ?? 1) == 1;
          _enableSchedule = (s['enable_schedule'] ?? 1) == 1;
          _enableTask = (s['enable_task'] ?? 1) == 1;
          _enableCloudDrive = (s['enable_cloud_drive'] ?? 1) == 1;
          _enableApproval = (s['enable_approval'] ?? 1) == 1;
          _enableAttendance = (s['enable_attendance'] ?? 1) == 1;
          _enableMeetingRoom = (s['enable_meeting_room'] ?? 1) == 1;
          _enableAnnouncement = (s['enable_announcement'] ?? 1) == 1;
          _enableVoting = (s['enable_voting'] ?? 1) == 1;
          _enableExpense = (s['enable_expense'] ?? 1) == 1;
          _enableCalendar = (s['enable_calendar'] ?? 1) == 1;
          _enableReport = (s['enable_report'] ?? 1) == 1;
          _enableAnalytics = (s['enable_analytics'] ?? 1) == 1;

          _recallTimeout = ((s['message_recall_timeout'] ?? 120) is int)
              ? ((s['message_recall_timeout'] ?? 120) / 60).round()
              : 2;
          _maxFileSize = s['max_file_size'] ?? 50;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    final res = await ApiService.enterpriseUpdateSettings({
      'allow_group_creation': _allowRegister ? 1 : 0,
      'require_approval': _requireApproval ? 1 : 0,
      'enable_voice_message': _enableVoiceMessage ? 1 : 0,
      'enable_image_send': _enableImageSend ? 1 : 0,
      'enable_video_send': _enableVideoSend ? 1 : 0,
      'enable_emoji': _enableEmoji ? 1 : 0,
      'enable_voice_call': _enableVoiceCall ? 1 : 0,
      'enable_video_call': _enableVideoCall ? 1 : 0,
      'enable_read_receipt': _enableReadReceipt ? 1 : 0,
      'enable_msg_recall': _enableMsgRecall ? 1 : 0,
      'enable_file_send': _enableFileSend ? 1 : 0,
      'enable_workbench': _enableWorkbench ? 1 : 0,
      'enable_schedule': _enableSchedule ? 1 : 0,
      'enable_task': _enableTask ? 1 : 0,
      'enable_cloud_drive': _enableCloudDrive ? 1 : 0,
      'enable_approval': _enableApproval ? 1 : 0,
      'enable_attendance': _enableAttendance ? 1 : 0,
      'enable_meeting_room': _enableMeetingRoom ? 1 : 0,
      'enable_announcement': _enableAnnouncement ? 1 : 0,
      'enable_voting': _enableVoting ? 1 : 0,
      'enable_expense': _enableExpense ? 1 : 0,
      'enable_calendar': _enableCalendar ? 1 : 0,
      'enable_report': _enableReport ? 1 : 0,
      'enable_analytics': _enableAnalytics ? 1 : 0,
      'message_recall_timeout': _recallTimeout * 60,
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
        _buildSection('基本设置', Icons.settings_outlined, [
          _buildSwitchTile('允许自主注册', '员工可通过企业ID自行注册账号', _allowRegister, (v) => setState(() => _allowRegister = v)),
          _buildSwitchTile('注册需审批', '新注册用户需管理员审批后方可使用', _requireApproval, (v) => setState(() => _requireApproval = v)),
        ]),
        const SizedBox(height: 20),
        _buildSection('聊天功能', Icons.chat_bubble_outline, [
          _buildSwitchTile('语音消息', '允许用户发送语音消息', _enableVoiceMessage, (v) => setState(() => _enableVoiceMessage = v)),
          _buildSwitchTile('发送图片', '允许用户在聊天中发送图片（支持多图最多9张）', _enableImageSend, (v) => setState(() => _enableImageSend = v)),
          _buildSwitchTile('发送视频', '允许用户在聊天中发送视频', _enableVideoSend, (v) => setState(() => _enableVideoSend = v)),
          _buildSwitchTile('Emoji表情', '允许用户发送Emoji表情', _enableEmoji, (v) => setState(() => _enableEmoji = v)),
          _buildSwitchTile('文件发送', '允许用户在聊天中发送文件', _enableFileSend, (v) => setState(() => _enableFileSend = v)),
          _buildSwitchTile('已读回执', '显示消息已读状态', _enableReadReceipt, (v) => setState(() => _enableReadReceipt = v)),
          _buildSwitchTile('消息撤回', '允许用户撤回已发送消息', _enableMsgRecall, (v) => setState(() => _enableMsgRecall = v)),
        ]),
        const SizedBox(height: 20),
        _buildSection('通话功能', Icons.call_outlined, [
          _buildSwitchTile('语音通话', '允许用户发起一对一语音通话', _enableVoiceCall, (v) => setState(() => _enableVoiceCall = v)),
          _buildSwitchTile('视频通话', '允许用户发起一对一视频通话', _enableVideoCall, (v) => setState(() => _enableVideoCall = v)),
        ]),
        const SizedBox(height: 20),
        _buildSection('工作台功能', Icons.apps_outlined, [
          _buildSwitchTile('工作台', '在前端显示工作台入口', _enableWorkbench, (v) => setState(() => _enableWorkbench = v)),
          _buildSwitchTile('日程安排', '日程管理和提醒功能', _enableSchedule, (v) => setState(() => _enableSchedule = v)),
          _buildSwitchTile('任务管理', '任务分配和跟踪功能', _enableTask, (v) => setState(() => _enableTask = v)),
          _buildSwitchTile('云盘', '企业文件云存储功能', _enableCloudDrive, (v) => setState(() => _enableCloudDrive = v)),
          _buildSwitchTile('审批', '在线审批流程功能', _enableApproval, (v) => setState(() => _enableApproval = v)),
          _buildSwitchTile('考勤打卡', '员工考勤管理功能', _enableAttendance, (v) => setState(() => _enableAttendance = v)),
          _buildSwitchTile('会议室预约', '会议室在线预约功能', _enableMeetingRoom, (v) => setState(() => _enableMeetingRoom = v)),
          _buildSwitchTile('公告通知', '企业公告发布功能', _enableAnnouncement, (v) => setState(() => _enableAnnouncement = v)),
          _buildSwitchTile('投票', '在线投票功能', _enableVoting, (v) => setState(() => _enableVoting = v)),
          _buildSwitchTile('报销', '费用报销管理功能', _enableExpense, (v) => setState(() => _enableExpense = v)),
          _buildSwitchTile('日历', '共享日历功能', _enableCalendar, (v) => setState(() => _enableCalendar = v)),
          _buildSwitchTile('工作报告', '日报/周报/月报功能', _enableReport, (v) => setState(() => _enableReport = v)),
          _buildSwitchTile('数据统计', '企业数据分析功能', _enableAnalytics, (v) => setState(() => _enableAnalytics = v)),
        ]),
        const SizedBox(height: 20),
        _buildSection('限制设置', Icons.tune_outlined, [
          _buildSliderTile('消息撤回时限', '$_recallTimeout 分钟内可撤回', _recallTimeout.toDouble(), 1, 10, (v) => setState(() => _recallTimeout = v.toInt())),
          _buildSliderTile('文件大小上限', '最大 $_maxFileSize MB', _maxFileSize.toDouble(), 10, 500, (v) => setState(() => _maxFileSize = v.toInt())),
        ]),
        const SizedBox(height: 24),
        Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(
          onPressed: _saveSettings, icon: const Icon(Icons.save, size: 18), label: const Text('保存设置'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
        const Divider(height: 1),
        ...children,
      ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
        Slider(value: value, min: min, max: max, divisions: (max - min).toInt(), onChanged: onChanged, activeColor: AppColors.primary),
      ]),
    );
  }
}
