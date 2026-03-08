import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

/// WebSocket服务 - 连接企业服务器实现实时消息和在线状态
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

  // 事件回调
  Function(Map<String, dynamic>)? onNewMessage;
  Function(Map<String, dynamic>)? onOnlineStatusChanged;
  Function(Map<String, dynamic>)? onMessageRecalled;
  Function(bool)? onConnectionChanged;

  /// 连接WebSocket
  void connect() {
    if (_isConnected) return;

    String wsUrl = ApiService.enterpriseWsUrl;
    if (wsUrl.isEmpty) {
      // 从企业API URL推导WebSocket URL
      String apiUrl = ApiService.enterpriseApiUrl;
      if (apiUrl.isEmpty) return;

      // 将http(s)://转为ws(s)://
      if (apiUrl.startsWith('https://')) {
        wsUrl = 'wss://' + apiUrl.substring(8);
      } else if (apiUrl.startsWith('http://')) {
        wsUrl = 'ws://' + apiUrl.substring(7);
      } else {
        return;
      }
      // 移除/api后缀
      if (wsUrl.endsWith('/api')) {
        wsUrl = wsUrl.substring(0, wsUrl.length - 4);
      }
    }

    final token = ApiService.userToken;
    if (token.isEmpty) return;

    try {
      final uri = Uri.parse('$wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          _onMessage(data);
        },
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

      _isConnected = true;
      _reconnectAttempts = 0;
      onConnectionChanged?.call(true);
      _startHeartbeat();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data.toString());
      final type = msg['type'] as String?;
      switch (type) {
        case 'new_message':
          onNewMessage?.call(msg['data'] ?? msg);
          break;
        case 'online_status':
          onOnlineStatusChanged?.call(msg['data'] ?? msg);
          break;
        case 'message_recalled':
          onMessageRecalled?.call(msg['data'] ?? msg);
          break;
        case 'pong':
          // 心跳响应
          break;
      }
    } catch (e) {
      // 忽略解析错误
    }
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
    _reconnectAttempts = _maxReconnectAttempts; // 防止重连
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
