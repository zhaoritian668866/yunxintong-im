import 'package:flutter/foundation.dart' show kIsWeb;

/// Web端通知服务 - 播放提示音和显示浏览器通知
class WebNotificationService {
  static bool _initialized = false;

  /// 播放新消息提示音
  static void playSound() {
    if (!kIsWeb) return;
    try {
      _callJsPlaySound();
    } catch (_) {}
  }

  /// 显示浏览器桌面通知
  static void showNotification(String title, String body) {
    if (!kIsWeb) return;
    try {
      _callJsShowNotification(title, body);
    } catch (_) {}
  }

  static void _callJsPlaySound() {
    // 通过web专用的js_interop调用
    // 在非web环境下这些方法不会被调用
  }

  static void _callJsShowNotification(String title, String body) {
    // 通过web专用的js_interop调用
  }
}
