import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

/// 通话类型
enum CallType { voice, video }

/// 通话状态
enum CallState { ringing, connecting, connected, ended }

/// 通话页面 - 支持语音通话和视频通话
class CallPage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String? targetUserAvatar;
  final CallType callType;
  final bool isIncoming; // 是否是来电
  final dynamic webSocketService; // WebSocket服务实例

  const CallPage({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    required this.callType,
    this.isIncoming = false,
    this.webSocketService,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with TickerProviderStateMixin {
  CallState _callState = CallState.ringing;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  Timer? _durationTimer;
  int _durationSeconds = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    if (!widget.isIncoming) {
      // 拨出电话，模拟连接过程
      _simulateCall();
    }
  }

  void _simulateCall() {
    // 模拟呼叫中...
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _callState == CallState.ringing) {
        setState(() => _callState = CallState.connecting);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && _callState == CallState.connecting) {
            setState(() => _callState = CallState.connected);
            _startDurationTimer();
          }
        });
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  String get _durationText {
    final m = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText {
    switch (_callState) {
      case CallState.ringing:
        return widget.isIncoming ? '来电...' : '呼叫中...';
      case CallState.connecting:
        return '连接中...';
      case CallState.connected:
        return _durationText;
      case CallState.ended:
        return '通话结束';
    }
  }

  void _acceptCall() {
    setState(() => _callState = CallState.connecting);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _callState = CallState.connected);
        _startDurationTimer();
      }
    });
  }

  void _hangUp() {
    _durationTimer?.cancel();
    setState(() => _callState = CallState.ended);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _rejectCall() {
    setState(() => _callState = CallState.ended);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _toggleMute() => setState(() => _isMuted = !_isMuted);
  void _toggleSpeaker() => setState(() => _isSpeakerOn = !_isSpeakerOn);
  void _toggleVideo() => setState(() => _isVideoEnabled = !_isVideoEnabled);
  void _switchCamera() => setState(() => _isFrontCamera = !_isFrontCamera);

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == CallType.video;

    return Scaffold(
      backgroundColor: isVideo ? Colors.black : const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(children: [
          // 视频通话背景
          if (isVideo && _callState == CallState.connected) ...[
            // 远端视频（全屏）
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.grey.shade900,
              child: Center(
                child: Icon(Icons.videocam, size: 80, color: Colors.grey.shade700),
              ),
            ),
            // 本地视频（小窗口）
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _isVideoEnabled
                      ? Center(child: Icon(Icons.person, size: 48, color: Colors.grey.shade600))
                      : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.videocam_off, size: 32, color: Colors.white54),
                          const SizedBox(height: 4),
                          const Text('摄像头已关', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ])),
                  ),
                ),
              ),
            ),
          ],

          // 语音通话或等待接通时的界面
          if (!isVideo || _callState != CallState.connected)
            Column(
              children: [
                const Spacer(flex: 2),
                // 头像
                _buildAvatar(),
                const SizedBox(height: 24),
                // 用户名
                Text(
                  widget.targetUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // 状态
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _callState == CallState.connected ? Colors.greenAccent : Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                // 通话类型标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isVideo ? '视频通话' : '语音通话',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),

          // 底部控制按钮
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: _buildControls(),
          ),
        ]),
      ),
    );
  }

  Widget _buildAvatar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _callState == CallState.ringing
          ? 1.0 + 0.05 * (_pulseController.value < 0.5 ? _pulseController.value : 1 - _pulseController.value)
          : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.2),
              border: Border.all(
                color: _callState == CallState.connected ? Colors.greenAccent.withOpacity(0.5) : Colors.white24,
                width: 3,
              ),
              boxShadow: _callState == CallState.ringing ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3 * (1 - _pulseController.value)),
                  blurRadius: 30 * _pulseController.value,
                  spreadRadius: 10 * _pulseController.value,
                ),
              ] : null,
            ),
            child: widget.targetUserAvatar != null
              ? ClipOval(child: Image.network(widget.targetUserAvatar!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _defaultAvatar()))
              : _defaultAvatar(),
          ),
        );
      },
    );
  }

  Widget _defaultAvatar() {
    return Center(
      child: Text(
        widget.targetUserName.isNotEmpty ? widget.targetUserName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildControls() {
    final isVideo = widget.callType == CallType.video;

    // 来电等待接听
    if (widget.isIncoming && _callState == CallState.ringing) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildControlButton(
          icon: Icons.call_end,
          label: '拒绝',
          color: Colors.red,
          onTap: _rejectCall,
          size: 64,
        ),
        _buildControlButton(
          icon: isVideo ? Icons.videocam : Icons.call,
          label: '接听',
          color: Colors.green,
          onTap: _acceptCall,
          size: 64,
        ),
      ]);
    }

    // 通话中或呼叫中
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // 功能按钮行
      if (_callState == CallState.connected)
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? '已静音' : '静音',
              color: _isMuted ? Colors.red : Colors.white24,
              onTap: _toggleMute,
            ),
            _buildControlButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: _isSpeakerOn ? '扬声器' : '听筒',
              color: _isSpeakerOn ? AppColors.primary : Colors.white24,
              onTap: _toggleSpeaker,
            ),
            if (isVideo) _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              label: _isVideoEnabled ? '摄像头' : '已关闭',
              color: _isVideoEnabled ? Colors.white24 : Colors.red,
              onTap: _toggleVideo,
            ),
            if (isVideo) _buildControlButton(
              icon: Icons.flip_camera_ios,
              label: '翻转',
              color: Colors.white24,
              onTap: _switchCamera,
            ),
          ]),
        ),
      // 挂断按钮
      _buildControlButton(
        icon: Icons.call_end,
        label: _callState == CallState.ringing ? '取消' : '挂断',
        color: Colors.red,
        onTap: _hangUp,
        size: 64,
      ),
    ]);
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}
