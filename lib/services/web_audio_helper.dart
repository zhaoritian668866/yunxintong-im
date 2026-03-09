/// Web平台音频录制和播放辅助类
/// 使用 dart:js_interop_unsafe 调用浏览器 MediaRecorder API
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 执行JavaScript代码
void _jsEval(String code) {
  globalContext.callMethod('eval'.toJS, code.toJS);
}

/// 执行JavaScript代码并返回字符串结果
String? _jsEvalString(String code) {
  try {
    final result = globalContext.callMethod('eval'.toJS, code.toJS);
    if (result == null) return null;
    if (result.isA<JSString>()) {
      final str = (result as JSString).toDart;
      return str.isNotEmpty ? str : null;
    }
    // 尝试转为字符串
    final strResult = globalContext.callMethod('String'.toJS, result);
    if (strResult != null && strResult.isA<JSString>()) {
      final s = (strResult as JSString).toDart;
      return s.isNotEmpty ? s : null;
    }
    return null;
  } catch (e) {
    return null;
  }
}

/// 开始录音
void startRecording() {
  _jsEval('''
    (function() {
      if (window._yunxinRecorder && window._yunxinRecorder.state === 'recording') return;
      window._yunxinAudioChunks = [];
      window._yunxinRecordedBase64 = '';
      window._yunxinRecordError = '';
      navigator.mediaDevices.getUserMedia({audio: true}).then(function(stream) {
        var options = {};
        if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
          options.mimeType = 'audio/webm;codecs=opus';
        } else if (MediaRecorder.isTypeSupported('audio/webm')) {
          options.mimeType = 'audio/webm';
        }
        var recorder = new MediaRecorder(stream, options);
        recorder.ondataavailable = function(e) {
          if (e.data && e.data.size > 0) {
            window._yunxinAudioChunks.push(e.data);
          }
        };
        recorder.onerror = function(e) {
          window._yunxinRecordError = 'recorder error';
          console.error('[WebAudio] MediaRecorder error:', e);
        };
        recorder.start(100);
        window._yunxinRecorder = recorder;
        window._yunxinStream = stream;
        console.log('[WebAudio] Recording started');
      }).catch(function(e) {
        window._yunxinRecordError = 'permission denied: ' + e.message;
        console.error('[WebAudio] getUserMedia failed:', e);
      });
    })();
  ''');
}

/// 停止录音并获取音频数据（返回字节数组）
Future<List<int>?> stopRecording() async {
  _jsEval('''
    (function() {
      window._yunxinRecordedBase64 = '';
      if (window._yunxinRecorder && window._yunxinRecorder.state !== 'inactive') {
        window._yunxinRecorder.onstop = function() {
          console.log('[WebAudio] Recorder stopped, chunks:', window._yunxinAudioChunks.length);
          if (window._yunxinAudioChunks.length === 0) {
            window._yunxinRecordedBase64 = 'EMPTY';
            return;
          }
          var blob = new Blob(window._yunxinAudioChunks, {type: 'audio/webm'});
          console.log('[WebAudio] Blob size:', blob.size);
          var reader = new FileReader();
          reader.onload = function() {
            var base64 = reader.result.split(',')[1];
            window._yunxinRecordedBase64 = base64 || 'EMPTY';
            console.log('[WebAudio] Base64 ready, length:', (base64 || '').length);
          };
          reader.onerror = function() {
            window._yunxinRecordedBase64 = 'ERROR';
            console.error('[WebAudio] FileReader error');
          };
          reader.readAsDataURL(blob);
        };
        window._yunxinRecorder.stop();
        if (window._yunxinStream) {
          window._yunxinStream.getTracks().forEach(function(t) { t.stop(); });
        }
        window._yunxinRecorder = null;
        window._yunxinStream = null;
      } else {
        window._yunxinRecordedBase64 = 'EMPTY';
      }
    })();
  ''');

  // 轮询等待数据就绪（最多5秒）
  for (int i = 0; i < 50; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final data = _jsEvalString('window._yunxinRecordedBase64 || ""');
    if (data != null && data.isNotEmpty) {
      _jsEval('window._yunxinRecordedBase64 = "";');
      if (data == 'EMPTY' || data == 'ERROR') {
        return null;
      }
      try {
        final bytes = base64Decode(data);
        return bytes;
      } catch (e) {
        return null;
      }
    }
  }
  return null;
}

/// 取消录音（不获取数据）
void cancelRecording() {
  _jsEval('''
    (function() {
      if (window._yunxinRecorder && window._yunxinRecorder.state !== 'inactive') {
        window._yunxinRecorder.onstop = function() {};
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
  final safeUrl = url.replaceAll("'", "\\'").replaceAll('"', '\\"');
  _jsEval('''
    (function(){
      if (window._yunxinAudioPlayer) {
        try { window._yunxinAudioPlayer.pause(); } catch(e) {}
        window._yunxinAudioPlayer = null;
      }
      var a = new Audio("$safeUrl");
      a.play().catch(function(e) { console.error('[WebAudio] play error:', e); });
      window._yunxinAudioPlayer = a;
    })();
  ''');
}
