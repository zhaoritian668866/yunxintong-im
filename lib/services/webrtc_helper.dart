/// Web平台 WebRTC 辅助类
/// 通过 dart:js_interop_unsafe 调用浏览器原生 RTCPeerConnection API
/// 实现真实的点对点音视频通话
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

/// 检查是否在安全上下文中（HTTPS 或 localhost）
bool isSecureContext() {
  final result = _jsEvalString('String(window.isSecureContext)');
  return result == 'true';
}

/// 初始化WebRTC全局对象和回调
void initWebRTC() {
  _jsEval(r'''
    (function() {
      if (window._yunxinRTC) return;
      window._yunxinRTC = {
        pc: null,
        localStream: null,
        remoteStream: null,
        iceCandidates: [],
        pendingIceCandidates: [],
        sdpOffer: '',
        sdpAnswer: '',
        state: 'idle',
        error: '',
        onIceCandidate: null,
        onTrack: null,
        onConnectionStateChange: null,
      };
      console.log('[WebRTC] Initialized');
    })();
  ''');
}

/// 创建RTCPeerConnection并获取本地媒体流
/// [isVideo] 是否包含视频
/// 返回是否成功
Future<bool> createPeerConnection({required bool isVideo}) async {
  initWebRTC();

  final mediaConstraints = isVideo
      ? '{ audio: true, video: { width: { ideal: 640 }, height: { ideal: 480 }, facingMode: "user" } }'
      : '{ audio: true, video: false }';

  _jsEval('''
    (async function() {
      try {
        window._yunxinRTC.state = 'creating';
        window._yunxinRTC.error = '';
        window._yunxinRTC.iceCandidates = [];
        window._yunxinRTC.pendingIceCandidates = [];
        window._yunxinRTC.sdpOffer = '';
        window._yunxinRTC.sdpAnswer = '';

        // STUN/TURN服务器配置
        var config = {
          iceServers: [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' },
            { urls: 'stun:stun2.l.google.com:19302' },
            { urls: 'stun:stun.stunprotocol.org:3478' }
          ],
          iceCandidatePoolSize: 10
        };

        // 创建PeerConnection
        var pc = new RTCPeerConnection(config);
        window._yunxinRTC.pc = pc;

        // ICE候选回调
        pc.onicecandidate = function(event) {
          if (event.candidate) {
            var c = {
              candidate: event.candidate.candidate,
              sdpMid: event.candidate.sdpMid,
              sdpMLineIndex: event.candidate.sdpMLineIndex
            };
            window._yunxinRTC.iceCandidates.push(JSON.stringify(c));
            console.log('[WebRTC] ICE candidate:', event.candidate.candidate.substring(0, 50));
          }
        };

        // 远端媒体流
        pc.ontrack = function(event) {
          console.log('[WebRTC] Remote track received:', event.track.kind);
          if (event.streams && event.streams[0]) {
            window._yunxinRTC.remoteStream = event.streams[0];
            // 将远端流绑定到audio/video元素
            var el = document.getElementById('yunxin-remote-media');
            if (el) {
              el.srcObject = event.streams[0];
              el.play().catch(function(e) { console.warn('[WebRTC] autoplay blocked:', e); });
            }
          }
        };

        // 连接状态变化
        pc.onconnectionstatechange = function() {
          window._yunxinRTC.connectionState = pc.connectionState;
          console.log('[WebRTC] Connection state:', pc.connectionState);
        };

        pc.oniceconnectionstatechange = function() {
          console.log('[WebRTC] ICE connection state:', pc.iceConnectionState);
        };

        // 获取本地媒体流
        var stream = await navigator.mediaDevices.getUserMedia($mediaConstraints);
        window._yunxinRTC.localStream = stream;

        // 将本地流的所有track添加到PeerConnection
        stream.getTracks().forEach(function(track) {
          pc.addTrack(track, stream);
          console.log('[WebRTC] Added local track:', track.kind);
        });

        // 将本地流绑定到本地预览元素
        var localEl = document.getElementById('yunxin-local-media');
        if (localEl) {
          localEl.srcObject = stream;
          localEl.muted = true;
          localEl.play().catch(function(e) { console.warn('[WebRTC] local autoplay blocked:', e); });
        }

        window._yunxinRTC.state = 'ready';
        console.log('[WebRTC] PeerConnection created, local stream ready');
      } catch(e) {
        window._yunxinRTC.state = 'error';
        window._yunxinRTC.error = e.message || 'Failed to create peer connection';
        console.error('[WebRTC] Error:', e);
      }
    })();
  ''');

  // 等待创建完成
  for (int i = 0; i < 100; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final state = _jsEvalString('window._yunxinRTC.state || ""');
    if (state == 'ready') return true;
    if (state == 'error') return false;
  }
  return false;
}

/// 创建SDP Offer（主叫方调用）
Future<String?> createOffer() async {
  _jsEval(r'''
    (async function() {
      try {
        var pc = window._yunxinRTC.pc;
        if (!pc) { window._yunxinRTC.sdpOffer = 'ERROR'; return; }
        var offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        window._yunxinRTC.sdpOffer = JSON.stringify(offer);
        console.log('[WebRTC] Offer created');
      } catch(e) {
        window._yunxinRTC.sdpOffer = 'ERROR';
        console.error('[WebRTC] Create offer error:', e);
      }
    })();
  ''');

  for (int i = 0; i < 50; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final sdp = _jsEvalString('window._yunxinRTC.sdpOffer || ""');
    if (sdp != null && sdp.isNotEmpty) {
      if (sdp == 'ERROR') return null;
      return sdp;
    }
  }
  return null;
}

/// 设置远端SDP Offer并创建Answer（被叫方调用）
Future<String?> createAnswer(String offerSdp) async {
  final safeOffer = offerSdp.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n').replaceAll('\r', '\\r');
  _jsEval('''
    (async function() {
      try {
        var pc = window._yunxinRTC.pc;
        if (!pc) { window._yunxinRTC.sdpAnswer = 'ERROR'; return; }
        var offer = JSON.parse('$safeOffer');
        await pc.setRemoteDescription(new RTCSessionDescription(offer));
        var answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        window._yunxinRTC.sdpAnswer = JSON.stringify(answer);
        console.log('[WebRTC] Answer created');

        // 处理之前缓存的ICE候选
        while (window._yunxinRTC.pendingIceCandidates.length > 0) {
          var c = window._yunxinRTC.pendingIceCandidates.shift();
          await pc.addIceCandidate(new RTCIceCandidate(c));
          console.log('[WebRTC] Added pending ICE candidate');
        }
      } catch(e) {
        window._yunxinRTC.sdpAnswer = 'ERROR';
        console.error('[WebRTC] Create answer error:', e);
      }
    })();
  ''');

  for (int i = 0; i < 50; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final sdp = _jsEvalString('window._yunxinRTC.sdpAnswer || ""');
    if (sdp != null && sdp.isNotEmpty) {
      if (sdp == 'ERROR') return null;
      return sdp;
    }
  }
  return null;
}

/// 设置远端SDP Answer（主叫方收到被叫方的answer后调用）
Future<bool> setRemoteAnswer(String answerSdp) async {
  final safeAnswer = answerSdp.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n').replaceAll('\r', '\\r');
  _jsEval('''
    (async function() {
      try {
        var pc = window._yunxinRTC.pc;
        if (!pc) { window._yunxinRTC.state = 'answer_error'; return; }
        var answer = JSON.parse('$safeAnswer');
        await pc.setRemoteDescription(new RTCSessionDescription(answer));
        window._yunxinRTC.state = 'answer_set';
        console.log('[WebRTC] Remote answer set');

        // 处理之前缓存的ICE候选
        while (window._yunxinRTC.pendingIceCandidates.length > 0) {
          var c = window._yunxinRTC.pendingIceCandidates.shift();
          await pc.addIceCandidate(new RTCIceCandidate(c));
          console.log('[WebRTC] Added pending ICE candidate');
        }
      } catch(e) {
        window._yunxinRTC.state = 'answer_error';
        console.error('[WebRTC] Set remote answer error:', e);
      }
    })();
  ''');

  for (int i = 0; i < 30; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final state = _jsEvalString('window._yunxinRTC.state || ""');
    if (state == 'answer_set') return true;
    if (state == 'answer_error') return false;
  }
  return false;
}

/// 添加远端ICE候选
void addIceCandidate(Map<String, dynamic> candidate) {
  final candidateJson = jsonEncode(candidate).replaceAll("'", "\\'");
  _jsEval('''
    (async function() {
      try {
        var pc = window._yunxinRTC.pc;
        var c = JSON.parse('$candidateJson');
        if (pc && pc.remoteDescription) {
          await pc.addIceCandidate(new RTCIceCandidate(c));
          console.log('[WebRTC] Added ICE candidate');
        } else {
          // 远端描述还没设置，先缓存
          window._yunxinRTC.pendingIceCandidates.push(c);
          console.log('[WebRTC] Cached ICE candidate (remote desc not set yet)');
        }
      } catch(e) {
        console.error('[WebRTC] Add ICE candidate error:', e);
      }
    })();
  ''');
}

/// 获取收集到的ICE候选列表（返回JSON字符串数组）
List<String> getIceCandidates() {
  final result = _jsEvalString(
    'JSON.stringify(window._yunxinRTC.iceCandidates || [])'
  );
  if (result == null || result.isEmpty || result == '[]') return [];
  try {
    final list = jsonDecode(result) as List;
    // 清空已获取的候选
    _jsEval('window._yunxinRTC.iceCandidates = [];');
    return list.cast<String>();
  } catch (e) {
    return [];
  }
}

/// 获取WebRTC连接状态
String getConnectionState() {
  return _jsEvalString(
    'window._yunxinRTC.pc ? window._yunxinRTC.pc.connectionState : "closed"'
  ) ?? 'closed';
}

/// 获取ICE连接状态
String getIceConnectionState() {
  return _jsEvalString(
    'window._yunxinRTC.pc ? window._yunxinRTC.pc.iceConnectionState : "closed"'
  ) ?? 'closed';
}

/// 切换本地音频静音
void toggleMute(bool mute) {
  _jsEval('''
    (function() {
      var stream = window._yunxinRTC.localStream;
      if (stream) {
        stream.getAudioTracks().forEach(function(t) { t.enabled = ${!mute}; });
        console.log('[WebRTC] Audio muted:', $mute);
      }
    })();
  ''');
}

/// 切换本地视频开关
void toggleVideo(bool enabled) {
  _jsEval('''
    (function() {
      var stream = window._yunxinRTC.localStream;
      if (stream) {
        stream.getVideoTracks().forEach(function(t) { t.enabled = $enabled; });
        console.log('[WebRTC] Video enabled:', $enabled);
      }
    })();
  ''');
}

/// 切换前后摄像头（移动端Web）
void switchCamera() {
  _jsEval(r'''
    (async function() {
      try {
        var stream = window._yunxinRTC.localStream;
        if (!stream) return;
        var videoTrack = stream.getVideoTracks()[0];
        if (!videoTrack) return;
        var settings = videoTrack.getSettings();
        var newFacing = settings.facingMode === 'user' ? 'environment' : 'user';
        var newStream = await navigator.mediaDevices.getUserMedia({
          audio: false,
          video: { facingMode: newFacing, width: { ideal: 640 }, height: { ideal: 480 } }
        });
        var newTrack = newStream.getVideoTracks()[0];
        var pc = window._yunxinRTC.pc;
        if (pc) {
          var sender = pc.getSenders().find(function(s) { return s.track && s.track.kind === 'video'; });
          if (sender) {
            await sender.replaceTrack(newTrack);
          }
        }
        videoTrack.stop();
        stream.removeTrack(videoTrack);
        stream.addTrack(newTrack);
        var localEl = document.getElementById('yunxin-local-media');
        if (localEl) localEl.srcObject = stream;
        console.log('[WebRTC] Camera switched to:', newFacing);
      } catch(e) {
        console.error('[WebRTC] Switch camera error:', e);
      }
    })();
  ''');
}

/// 关闭WebRTC连接，释放所有资源
void closeConnection() {
  _jsEval(r'''
    (function() {
      if (window._yunxinRTC) {
        if (window._yunxinRTC.localStream) {
          window._yunxinRTC.localStream.getTracks().forEach(function(t) { t.stop(); });
          window._yunxinRTC.localStream = null;
        }
        if (window._yunxinRTC.remoteStream) {
          window._yunxinRTC.remoteStream.getTracks().forEach(function(t) { t.stop(); });
          window._yunxinRTC.remoteStream = null;
        }
        if (window._yunxinRTC.pc) {
          window._yunxinRTC.pc.close();
          window._yunxinRTC.pc = null;
        }
        window._yunxinRTC.state = 'idle';
        window._yunxinRTC.iceCandidates = [];
        window._yunxinRTC.pendingIceCandidates = [];
        window._yunxinRTC.sdpOffer = '';
        window._yunxinRTC.sdpAnswer = '';
        console.log('[WebRTC] Connection closed, resources released');
      }
      // 清理媒体元素
      var remoteEl = document.getElementById('yunxin-remote-media');
      if (remoteEl) { remoteEl.srcObject = null; }
      var localEl = document.getElementById('yunxin-local-media');
      if (localEl) { localEl.srcObject = null; }
    })();
  ''');
}

/// 在页面中注入音视频HTML元素（用于播放远端和本地流）
void injectMediaElements(bool isVideo) {
  if (isVideo) {
    _jsEval(r'''
      (function() {
        // 远端视频
        if (!document.getElementById('yunxin-remote-media')) {
          var v = document.createElement('video');
          v.id = 'yunxin-remote-media';
          v.autoplay = true;
          v.playsinline = true;
          v.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;object-fit:cover;z-index:9998;background:#000;';
          document.body.appendChild(v);
        }
        // 本地视频（小窗口）
        if (!document.getElementById('yunxin-local-media')) {
          var lv = document.createElement('video');
          lv.id = 'yunxin-local-media';
          lv.autoplay = true;
          lv.playsinline = true;
          lv.muted = true;
          lv.style.cssText = 'position:fixed;top:60px;right:16px;width:120px;height:160px;object-fit:cover;z-index:10001;border-radius:12px;border:2px solid rgba(255,255,255,0.3);background:#333;';
          document.body.appendChild(lv);
        }
      })();
    ''');
  } else {
    _jsEval(r'''
      (function() {
        // 语音通话只需要audio元素
        if (!document.getElementById('yunxin-remote-media')) {
          var a = document.createElement('audio');
          a.id = 'yunxin-remote-media';
          a.autoplay = true;
          a.style.cssText = 'position:fixed;top:-9999px;';
          document.body.appendChild(a);
        }
      })();
    ''');
  }
}

/// 移除注入的媒体元素
void removeMediaElements() {
  _jsEval(r'''
    (function() {
      var el = document.getElementById('yunxin-remote-media');
      if (el) el.remove();
      var lel = document.getElementById('yunxin-local-media');
      if (lel) lel.remove();
    })();
  ''');
}
