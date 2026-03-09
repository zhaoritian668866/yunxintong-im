/// Web平台音频录制和播放辅助类
/// 使用 dart:js_interop 调用浏览器 MediaRecorder API
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

@JS('eval')
external JSAny? _jsEval(JSString code);

@JS('JSON.stringify')
external JSString _jsStringify(JSAny? obj);

/// 执行JavaScript代码
void jsEval(String code) {
  _jsEval(code.toJS);
}

/// 执行JavaScript代码并返回字符串结果
String? jsEvalString(String code) {
  try {
    final result = _jsEval(code.toJS);
    if (result == null) return null;
    final str = (result as JSString).toDart;
    return str.isNotEmpty ? str : null;
  } catch (_) {
    return null;
  }
}

/// 开始录音
void startRecording() {
  jsEval('''
    (function() {
      if (window._yunxinRecorder) return;
      navigator.mediaDevices.getUserMedia({audio: true}).then(function(stream) {
        window._yunxinAudioChunks = [];
        window._yunxinRecordedBase64 = '';
        var recorder = new MediaRecorder(stream);
        recorder.ondataavailable = function(e) {
          window._yunxinAudioChunks.push(e.data);
        };
        recorder.start();
        window._yunxinRecorder = recorder;
        window._yunxinStream = stream;
      }).catch(function(e) {
        console.error('录音权限获取失败:', e);
      });
    })();
  ''');
}

/// 停止录音并获取base64数据
Future<List<int>?> stopRecording() async {
  jsEval('''
    (function() {
      if (window._yunxinRecorder && window._yunxinRecorder.state !== 'inactive') {
        window._yunxinRecorder.onstop = function() {
          var blob = new Blob(window._yunxinAudioChunks, {type: 'audio/webm'});
          var reader = new FileReader();
          reader.onload = function() {
            window._yunxinRecordedBase64 = reader.result.split(',')[1];
          };
          reader.readAsDataURL(blob);
        };
        window._yunxinRecorder.stop();
        if (window._yunxinStream) {
          window._yunxinStream.getTracks().forEach(function(t) { t.stop(); });
        }
        window._yunxinRecorder = null;
        window._yunxinStream = null;
      }
    })();
  ''');

  // 轮询等待数据就绪
  for (int i = 0; i < 30; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final data = jsEvalString('window._yunxinRecordedBase64 || ""');
    if (data != null && data.isNotEmpty) {
      jsEval('window._yunxinRecordedBase64 = ""');
      try {
        return base64Decode(data);
      } catch (_) {}
    }
  }
  return null;
}

/// 取消录音（不获取数据）
void cancelRecording() {
  jsEval('''
    (function() {
      if (window._yunxinRecorder && window._yunxinRecorder.state !== 'inactive') {
        window._yunxinRecorder.stop();
      }
      if (window._yunxinStream) {
        window._yunxinStream.getTracks().forEach(function(t) { t.stop(); });
      }
      window._yunxinRecorder = null;
      window._yunxinStream = null;
      window._yunxinAudioChunks = [];
      window._yunxinRecordedBase64 = '';
    })();
  ''');
}

/// 播放音频URL
void playAudio(String url) {
  // 转义URL中的特殊字符
  final safeUrl = url.replaceAll("'", "\\'").replaceAll('"', '\\"');
  jsEval('(function(){ var a = new Audio("$safeUrl"); a.play(); })()');
}
