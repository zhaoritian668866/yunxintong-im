// Web-specific JS interop for notification sounds
// This file should only be imported conditionally on web platform

import 'dart:js_interop';

@JS('playNotificationSound')
external void _jsPlayNotificationSound();

@JS('showBrowserNotification')
external void _jsShowBrowserNotification(JSString title, JSString body);

void webPlayNotificationSound() {
  try {
    _jsPlayNotificationSound();
  } catch (_) {}
}

void webShowBrowserNotification(String title, String body) {
  try {
    _jsShowBrowserNotification(title.toJS, body.toJS);
  } catch (_) {}
}
