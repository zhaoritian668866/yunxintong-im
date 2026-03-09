import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

/// WebSocket服务 - 连接企业服务器实现实时消息、在线状态和WebRTC信令
class WsService {
  static WsService? _instance;
  static WsService get instance => _instance ??= WsService._();
  WsService._();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;

  // IM事件回调
  Function(Map<String, dynamic>)? onNewMessage;
  Function(Map<String, dynamic>)? onOnlineStatusChanged;
  Function(Map<String, dynamic>)? onMessageRecalled;
  Function(bool)? onConnectionChanged;
  /// 功能开关变更回调（后台修改设置后即时推送）
  Function(Map<String, dynamic>)? onSettingsChanged;

  // ==================== WebRTC通话信令回调 ====================
  /// 收到来电（对方发起call_offer）
  Function(Map<String, dynamic>)? onCallOffer;
  /// 对方接听（收到call_answer）
  Function(Map<String, dynamic>)? onCallAnswer;
  /// 收到ICE候选
  Function(Map<String, dynamic>)? onIceCandidate;
  /// 对方挂断
  Function(Map<String, dynamic>)? onCallHangup;
  /// 对方拒绝
  Function(Map<String, dynamic>)? onCallReject;
  /// 通话错误（如对方不在线）
  Function(Map<String, dynamic>)? onCallError;

  /// 连接WebSocket
  void connect() {
    if (_isConnected) return;

    final token = ApiService.userToken;
    if (token.isEmpty) return;

    final enterpriseId = ApiService.enterpriseId;
    if (enterpriseId.isEmpty) return;

    String wsUrl = ApiService.enterpriseWsUrl;
    String fullWsUrl;

    if (wsUrl.isNotEmpty) {
      // 有直连WebSocket地址
      fullWsUrl = '$wsUrl?token=$token';
    } else {
      // 通过SaaS代理WebSocket: ws(s)://saas-host/ws/{enterprise_id}?token=xxx
      final origin = Uri.base.origin;
      final wsScheme = origin.startsWith('https') ? 'wss' : 'ws';
      final host = Uri.base.host;
      final port = Uri.base.port;
      final portStr = (port == 80 || port == 443) ? '' : ':$port';
      fullWsUrl = '$wsScheme://$host$portStr/ws/$enterpriseId?token=$token';
    }

    try {
      final uri = Uri.parse(fullWsUrl);
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) => _onMessage(data),
        onDone: () {
          _isConnected = false;
          onConnectionChanged?.call(false);
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          onConnectionChanged?.call(false);
          _scheduleReconnect();
        },
      );

      // 连接成功后发送认证消息
      _isConnected = true;
      _reconnectAttempts = 0;
      onConnectionChanged?.call(true);
      _startHeartbeat();

      // 发送认证
      send({'type': 'auth', 'token': token});
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data.toString());
      final type = msg['type'] as String?;
      switch (type) {
        // IM消息
        case 'new_message':
          onNewMessage?.call(msg['data'] ?? msg);
          break;
        case 'online_status':
          onOnlineStatusChanged?.call(msg);
          break;
        case 'message_recalled':
          onMessageRecalled?.call(msg['data'] ?? msg);
          break;
        case 'auth_success':
          // 认证成功
          break;
        case 'auth_error':
          // 认证失败
          break;
        case 'pong':
          break;
        case 'settings_changed':
          onSettingsChanged?.call(msg['data'] ?? {});
          break;

        // ==================== WebRTC通话信令 ====================
        case 'call_offer':
          onCallOffer?.call(msg);
          break;
        case 'call_answer':
          onCallAnswer?.call(msg);
          break;
        case 'ice_candidate':
          onIceCandidate?.call(msg);
          break;
        case 'call_hangup':
          onCallHangup?.call(msg);
          break;
        case 'call_reject':
          onCallReject?.call(msg);
          break;
        case 'call_error':
          onCallError?.call(msg);
          break;
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  /// 发送JSON消息
  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        // 发送失败
      }
    }
  }

  // ==================== WebRTC信令发送方法 ====================

  /// 发起通话（发送SDP offer）
  void sendCallOffer({
    required String targetUserId,
    required String callType,
    required String sdp,
    String? conversationId,
  }) {
    send({
      'type': 'call_offer',
      'target_user_id': targetUserId,
      'call_type': callType,
      'sdp': sdp,
      'conversation_id': conversationId ?? '',
    });
  }

  /// 接听通话（发送SDP answer）
  void sendCallAnswer({
    required String targetUserId,
    required String sdp,
  }) {
    send({
      'type': 'call_answer',
      'target_user_id': targetUserId,
      'sdp': sdp,
    });
  }

  /// 发送ICE候选
  void sendIceCandidate({
    required String targetUserId,
    required Map<String, dynamic> candidate,
  }) {
    send({
      'type': 'ice_candidate',
      'target_user_id': targetUserId,
      'candidate': candidate,
    });
  }

  /// 挂断通话
  void sendCallHangup({
    required String targetUserId,
    String reason = 'hangup',
  }) {
    send({
      'type': 'call_hangup',
      'target_user_id': targetUserId,
      'reason': reason,
    });
  }

  /// 拒绝通话
  void sendCallReject({
    required String targetUserId,
    String reason = 'rejected',
  }) {
    send({
      'type': 'call_reject',
      'target_user_id': targetUserId,
      'reason': reason,
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          _isConnected = false;
          onConnectionChanged?.call(false);
          _scheduleReconnect();
        }
      }
    });
  }

  void _scheduleReconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  /// 断开连接
  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _isConnected = false;
    _reconnectAttempts = _maxReconnectAttempts;
    try {
      _channel?.sink.close();
    } catch (e) {}
    _channel = null;
    onConnectionChanged?.call(false);
  }

  /// 重置并重新连接
  void reconnect() {
    disconnect();
    _reconnectAttempts = 0;
    connect();
  }

  bool get isConnected => _isConnected;
}
