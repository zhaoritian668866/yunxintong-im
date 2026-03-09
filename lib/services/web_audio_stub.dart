/// 非Web平台的音频辅助类存根
/// 在非Web平台上这些方法不会被调用
library;

import 'dart:async';

bool isSecureContext() => true;

Future<String> checkMicrophonePermission() async => 'granted';

Future<bool> startRecordingAsync() async => false;

void startRecording() {}

Future<List<int>?> stopRecording() async => null;

void cancelRecording() {}

void playAudio(String url) {}

void playVideo(String url) {}

void downloadFile(String url, String filename) {}
