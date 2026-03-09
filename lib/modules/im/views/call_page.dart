import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../config/theme.dart';
import '../../../services/ws_service.dart';
import '../../../services/webrtc_helper.dart'
  if (dart.library.io) '../../../services/webrtc_stub.dart' as webrtc;

/// 通话类型
enum CallType { voice, video }

/// 通话状态
enum CallState { initializing, ringing, connecting, connected, ended, error }

/// 真实WebRTC通话页面
class CallPage extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String? targetUserAvatar;
  final CallType callType;
  final bool isIncoming;
  final Map<String, dynamic>? incomingOffer; // 来电时的SDP offer数据

  const CallPage({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    required this.callType,
    this.isIncoming = false,
    this.incomingOffer,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with TickerProviderStateMixin {
  CallState _callState = CallState.initializing;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = true;
  Timer? _durationTimer;
  Timer? _iceTimer;
  int _durationSeconds = 0;
  late AnimationController _pulseController;
  String _errorMessage = '';

  // 保存原始回调以便恢复
  Function(Map<String, dynamic>)? _prevOnCallAnswer;
  Function(Map<String, dynamic>)? _prevOnIceCandidate;
  Function(Map<String, dynamic>)? _prevOnCallHangup;
  Function(Map<String, dynamic>)? _prevOnCallReject;
  Function(Map<String, dynamic>)? _prevOnCallError;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _setupSignalingCallbacks();

    if (widget.isIncoming) {
      // 来电 - 等待用户接听
      setState(() => _callState = CallState.ringing);
    } else {
      // 主叫 - 初始化WebRTC并发起呼叫
      _initiateOutgoingCall();
    }
  }

  /// 设置WebSocket信令回调
  void _setupSignalingCallbacks() {
    final ws = WsService.instance;

    // 保存原始回调
    _prevOnCallAnswer = ws.onCallAnswer;
    _prevOnIceCandidate = ws.onIceCandidate;
    _prevOnCallHangup = ws.onCallHangup;
    _prevOnCallReject = ws.onCallReject;
    _prevOnCallError = ws.onCallError;

    // 设置通话信令回调
    ws.onCallAnswer = _onCallAnswer;
    ws.onIceCandidate = _onIceCandidate;
    ws.onCallHangup = _onCallHangup;
    ws.onCallReject = _onCallReject;
    ws.onCallError = _onCallError;
  }

  /// 恢复原始回调
  void _restoreCallbacks() {
    final ws = WsService.instance;
    ws.onCallAnswer = _prevOnCallAnswer;
    ws.onIceCandidate = _prevOnIceCandidate;
    ws.onCallHangup = _prevOnCallHangup;
    ws.onCallReject = _prevOnCallReject;
    ws.onCallError = _prevOnCallError;
  }

  // ==================== 主叫流程 ====================

  /// 发起外呼
  Future<void> _initiateOutgoingCall() async {
    if (!kIsWeb) {
      _setError('通话功能仅支持Web平台');
      return;
    }

    // 检查安全上下文（HTTP下无法使用麦克风/摄像头）
    if (!webrtc.isSecureContext()) {
      _setError('需要HTTPS才能使用音视频通话\n请使用HTTPS访问或在浏览器设置中将此站点添加为安全站点');
      return;
    }

    setState(() => _callState = CallState.initializing);

    // 注入媒体元素
    final isVideo = widget.callType == CallType.video;
    webrtc.injectMediaElements(isVideo);

    // 创建PeerConnection并获取本地媒体流
    final success = await webrtc.createPeerConnection(isVideo: isVideo);
    if (!success) {
      _setError('无法获取麦克风${isVideo ? "/摄像头" : ""}权限，请在浏览器中允许访问');
      return;
    }

    // 创建SDP Offer
    final offerSdp = await webrtc.createOffer();
    if (offerSdp == null) {
      _setError('创建通话请求失败');
      return;
    }

    // 通过WebSocket发送呼叫请求
    WsService.instance.sendCallOffer(
      targetUserId: widget.targetUserId,
      callType: isVideo ? 'video' : 'voice',
      sdp: offerSdp,
    );

    if (mounted) {
      setState(() => _callState = CallState.ringing);
    }

    // 开始定期发送ICE候选
    _startIceCandidateTimer();

    // 30秒无应答自动挂断
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _callState == CallState.ringing) {
        _hangUp(reason: 'timeout');
      }
    });
  }

  // ==================== 被叫流程 ====================

  /// 接听来电
  Future<void> _acceptCall() async {
    if (!kIsWeb) return;

    // 检查安全上下文
    if (!webrtc.isSecureContext()) {
      _setError('需要HTTPS才能接听通话\n请使用HTTPS访问');
      return;
    }

    setState(() => _callState = CallState.connecting);

    final isVideo = widget.callType == CallType.video;
    webrtc.injectMediaElements(isVideo);

    // 创建PeerConnection
    final success = await webrtc.createPeerConnection(isVideo: isVideo);
    if (!success) {
      _setError('无法获取麦克风${isVideo ? "/摄像头" : ""}权限');
      return;
    }

    // 设置远端Offer并创建Answer
    final offerSdp = widget.incomingOffer?['sdp'] ?? '';
    if (offerSdp.isEmpty) {
      _setError('无效的通话请求');
      return;
    }

    final answerSdp = await webrtc.createAnswer(offerSdp);
    if (answerSdp == null) {
      _setError('接听失败');
      return;
    }

    // 发送Answer
    WsService.instance.sendCallAnswer(
      targetUserId: widget.targetUserId,
      sdp: answerSdp,
    );

    // 开始发送ICE候选
    _startIceCandidateTimer();

    if (mounted) {
      setState(() => _callState = CallState.connected);
      _startDurationTimer();
    }
  }

  /// 拒绝来电
  void _rejectCall() {
    WsService.instance.sendCallReject(
      targetUserId: widget.targetUserId,
      reason: 'rejected',
    );
    _endCall();
  }

  // ==================== 信令回调 ====================

  /// 收到对方的Answer（主叫方）
  void _onCallAnswer(Map<String, dynamic> msg) async {
    final sdp = msg['sdp'];
    if (sdp == null) return;

    final sdpStr = sdp is String ? sdp : jsonEncode(sdp);
    final success = await webrtc.setRemoteAnswer(sdpStr);
    if (success && mounted) {
      setState(() => _callState = CallState.connected);
      _startDurationTimer();
    }
  }

  /// 收到ICE候选
  void _onIceCandidate(Map<String, dynamic> msg) {
    final candidate = msg['candidate'];
    if (candidate != null && candidate is Map) {
      webrtc.addIceCandidate(Map<String, dynamic>.from(candidate));
    }
  }

  /// 对方挂断
  void _onCallHangup(Map<String, dynamic> msg) {
    _endCall();
  }

  /// 对方拒绝
  void _onCallReject(Map<String, dynamic> msg) {
    final reason = msg['reason'] ?? 'rejected';
    if (mounted) {
      setState(() {
        _callState = CallState.ended;
        _errorMessage = reason == 'busy' ? '对方忙线中' : '对方已拒绝';
      });
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// 通话错误
  void _onCallError(Map<String, dynamic> msg) {
    _setError(msg['message'] ?? '通话失败');
  }

  // ==================== ICE候选定时发送 ====================

  void _startIceCandidateTimer() {
    _iceTimer?.cancel();
    _iceTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final candidates = webrtc.getIceCandidates();
      for (final c in candidates) {
        try {
          final candidate = jsonDecode(c);
          WsService.instance.sendIceCandidate(
            targetUserId: widget.targetUserId,
            candidate: Map<String, dynamic>.from(candidate),
          );
        } catch (e) {
          // 忽略解析错误
        }
      }

      // 检查连接状态
      if (_callState == CallState.connected) {
        final state = webrtc.getIceConnectionState();
        if (state == 'disconnected' || state == 'failed' || state == 'closed') {
          _endCall();
        }
      }
    });
  }

  // ==================== 通话控制 ====================

  void _hangUp({String reason = 'hangup'}) {
    WsService.instance.sendCallHangup(
      targetUserId: widget.targetUserId,
      reason: reason,
    );
    _endCall();
  }

  void _endCall() {
    _durationTimer?.cancel();
    _iceTimer?.cancel();
    webrtc.closeConnection();
    webrtc.removeMediaElements();
    if (mounted) {
      setState(() => _callState = CallState.ended);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _callState = CallState.error;
        _errorMessage = message;
      });
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        webrtc.closeConnection();
        webrtc.removeMediaElements();
        Navigator.of(context).pop();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    webrtc.toggleMute(_isMuted);
  }

  void _toggleVideo() {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    webrtc.toggleVideo(_isVideoEnabled);
  }

  void _switchCamera() {
    webrtc.switchCamera();
  }

  String get _durationText {
    final m = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText {
    switch (_callState) {
      case CallState.initializing:
        return '正在准备...';
      case CallState.ringing:
        return widget.isIncoming ? '来电...' : '呼叫中...';
      case CallState.connecting:
        return '连接中...';
      case CallState.connected:
        return _durationText;
      case CallState.ended:
        return '通话结束';
      case CallState.error:
        return _errorMessage;
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _iceTimer?.cancel();
    _pulseController.dispose();
    _restoreCallbacks();
    // 确保资源释放
    if (_callState != CallState.ended) {
      webrtc.closeConnection();
      webrtc.removeMediaElements();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == CallType.video;

    return Scaffold(
      backgroundColor: isVideo ? Colors.black : const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(children: [
          // 视频通话时的背景提示（真实视频通过HTML元素渲染在Flutter层之下）
          if (isVideo && _callState == CallState.connected) ...[
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Text('视频通话中', style: TextStyle(color: Colors.white38, fontSize: 14)),
              ),
            ),
          ],

          // 语音通话或等待接通时的界面
          if (!isVideo || _callState != CallState.connected)
            Column(
              children: [
                const Spacer(flex: 2),
                _buildAvatar(),
                const SizedBox(height: 24),
                Text(
                  widget.targetUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _callState == CallState.connected ? Colors.greenAccent
                         : _callState == CallState.error ? Colors.redAccent
                         : Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isVideo ? Icons.videocam : Icons.call,
                      color: Colors.white60,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVideo ? '视频通话' : '语音通话',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ]),
                ),
                if (_callState == CallState.error) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
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

    // 错误状态 - 只显示关闭按钮
    if (_callState == CallState.error) {
      return Center(
        child: _buildControlButton(
          icon: Icons.close,
          label: '关闭',
          color: Colors.red,
          onTap: () {
            webrtc.closeConnection();
            webrtc.removeMediaElements();
            Navigator.of(context).pop();
          },
          size: 64,
        ),
      );
    }

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
      _buildControlButton(
        icon: Icons.call_end,
        label: _callState == CallState.ringing ? '取消' : '挂断',
        color: Colors.red,
        onTap: () => _hangUp(),
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
