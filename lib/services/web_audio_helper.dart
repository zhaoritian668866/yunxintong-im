/// Web平台音频录制和播放辅助类
/// 使用 dart:js_interop_unsafe 调用浏览器 MediaRecorder API
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// 执行JavaScript代码（无返回值）
void _jsEval(String code) {
  try {
    globalContext.callMethod('eval'.toJS, code.toJS);
  } catch (e) {
    // ignore eval errors
  }
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
    return null;
  } catch (e) {
    return null;
  }
}

/// 检查是否在安全上下文中（HTTPS 或 localhost）
bool isSecureContext() {
  final result = _jsEvalString('String(window.isSecureContext)');
  return result == 'true';
}

/// 检查麦克风权限状态
/// 返回: 'granted', 'denied', 'prompt', 'unsupported', 'insecure'
Future<String> checkMicrophonePermission() async {
  // 先检查是否在安全上下文中
  if (!isSecureContext()) {
    return 'insecure';
  }
  
  // 检查是否支持 mediaDevices
  final supported = _jsEvalString(
    'String(typeof navigator !== "undefined" && navigator.mediaDevices && typeof navigator.mediaDevices.getUserMedia === "function")'
  );
  if (supported != 'true') {
    return 'unsupported';
  }
  
  // 尝试查询权限状态
  _jsEval('''
    (function() {
      window._yunxinMicPermission = 'checking';
      if (navigator.permissions && navigator.permissions.query) {
        navigator.permissions.query({name: 'microphone'}).then(function(result) {
          window._yunxinMicPermission = result.state;
        }).catch(function() {
          window._yunxinMicPermission = 'prompt';
        });
      } else {
        window._yunxinMicPermission = 'prompt';
      }
    })();
  ''');
  
  // 等待结果
  for (int i = 0; i < 20; i++) {
    await Future.delayed(const Duration(milliseconds: 50));
    final state = _jsEvalString('window._yunxinMicPermission || ""');
    if (state != null && state != 'checking' && state.isNotEmpty) {
      return state;
    }
  }
  return 'prompt';
}

/// 开始录音（异步，等待权限授予）
/// 返回 true 表示录音成功开始，false 表示失败
Future<bool> startRecordingAsync() async {
  // 先检查安全上下文
  if (!isSecureContext()) {
    return false;
  }
  
  _jsEval('''
    (function() {
      window._yunxinRecordStartResult = 'pending';
      window._yunxinAudioChunks = [];
      window._yunxinRecordedBase64 = '';
      window._yunxinRecordError = '';
      
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        window._yunxinRecordStartResult = 'unsupported';
        return;
      }
      
      navigator.mediaDevices.getUserMedia({audio: true}).then(function(stream) {
        var options = {};
        if (typeof MediaRecorder !== 'undefined') {
          if (MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
            options.mimeType = 'audio/webm;codecs=opus';
          } else if (MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported('audio/webm')) {
            options.mimeType = 'audio/webm';
          }
        }
        try {
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
          window._yunxinRecordStartResult = 'success';
          console.log('[WebAudio] Recording started');
        } catch(e) {
          stream.getTracks().forEach(function(t) { t.stop(); });
          window._yunxinRecordStartResult = 'error:' + e.message;
          console.error('[WebAudio] MediaRecorder init failed:', e);
        }
      }).catch(function(e) {
        window._yunxinRecordStartResult = 'denied:' + e.message;
        console.error('[WebAudio] getUserMedia failed:', e);
      });
    })();
  ''');
  
  // 等待结果（最多5秒）
  for (int i = 0; i < 50; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final result = _jsEvalString('window._yunxinRecordStartResult || ""');
    if (result != null && result != 'pending' && result.isNotEmpty) {
      return result == 'success';
    }
  }
  return false;
}

/// 同步开始录音（兼容旧接口，但不推荐）
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
        };
        recorder.start(100);
        window._yunxinRecorder = recorder;
        window._yunxinStream = stream;
      }).catch(function(e) {
        window._yunxinRecordError = 'permission denied: ' + e.message;
      });
    })();
  ''');
}

/// 停止录音并获取音频数据（返回字节数组）
Future<List<int>?> stopRecording() async {
  // 检查是否有活跃的录音器
  final hasRecorder = _jsEvalString(
    'String(window._yunxinRecorder && window._yunxinRecorder.state !== "inactive")'
  );
  
  if (hasRecorder != 'true') {
    // 没有活跃的录音器，清理并返回null
    _jsEval('''
      window._yunxinRecordedBase64 = '';
      window._yunxinAudioChunks = [];
    ''');
    return null;
  }
  
  _jsEval('''
    (function() {
      window._yunxinRecordedBase64 = '';
      try {
        if (window._yunxinRecorder && window._yunxinRecorder.state !== 'inactive') {
          window._yunxinRecorder.onstop = function() {
            console.log('[WebAudio] Recorder stopped, chunks:', window._yunxinAudioChunks.length);
            if (!window._yunxinAudioChunks || window._yunxinAudioChunks.length === 0) {
              window._yunxinRecordedBase64 = 'EMPTY';
              return;
            }
            var blob = new Blob(window._yunxinAudioChunks, {type: 'audio/webm'});
            console.log('[WebAudio] Blob size:', blob.size);
            var reader = new FileReader();
            reader.onload = function() {
              try {
                var base64 = reader.result.split(',')[1];
                window._yunxinRecordedBase64 = base64 || 'EMPTY';
                console.log('[WebAudio] Base64 ready, length:', (base64 || '').length);
              } catch(e) {
                window._yunxinRecordedBase64 = 'ERROR';
              }
            };
            reader.onerror = function() {
              window._yunxinRecordedBase64 = 'ERROR';
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
      } catch(e) {
        console.error('[WebAudio] stop error:', e);
        window._yunxinRecordedBase64 = 'ERROR';
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
      try {
        if (window._yunxinRecorder && window._yunxinRecorder.state !== 'inactive') {
          window._yunxinRecorder.onstop = function() {};
          window._yunxinRecorder.stop();
        }
        if (window._yunxinStream) {
          window._yunxinStream.getTracks().forEach(function(t) { t.stop(); });
        }
      } catch(e) {}
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
      try {
        if (window._yunxinAudioPlayer) {
          try { window._yunxinAudioPlayer.pause(); } catch(e) {}
          window._yunxinAudioPlayer = null;
        }
        var a = new Audio("$safeUrl");
        a.play().catch(function(e) { console.error('[WebAudio] play error:', e); });
        window._yunxinAudioPlayer = a;
      } catch(e) {
        console.error('[WebAudio] playAudio error:', e);
      }
    })();
  ''');
}

/// 在新窗口打开视频播放
void playVideo(String url) {
  final safeUrl = url.replaceAll("'", "\\'").replaceAll('"', '\\"');
  _jsEval('''
    (function(){
      try {
        var w = window.open('', '_blank', 'width=800,height=600');
        if (w) {
          w.document.write('<html><head><title>视频播放</title><style>body{margin:0;background:#000;display:flex;align-items:center;justify-content:center;height:100vh}video{max-width:100%;max-height:100%}</style></head><body><video controls autoplay src="$safeUrl"></video></body></html>');
          w.document.close();
        } else {
          window.open("$safeUrl", '_blank');
        }
      } catch(e) {
        window.open("$safeUrl", '_blank');
      }
    })();
  ''');
}

/// 下载文件
void downloadFile(String url, String filename) {
  final safeUrl = url.replaceAll("'", "\\'").replaceAll('"', '\\"');
  final safeName = filename.replaceAll("'", "\\'").replaceAll('"', '\\"');
  _jsEval('''
    (function(){
      try {
        var a = document.createElement('a');
        a.href = "$safeUrl";
        a.download = "$safeName";
        a.target = '_blank';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      } catch(e) {
        window.open("$safeUrl", '_blank');
      }
    })();
  ''');
}
