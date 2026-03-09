/// 非Web平台的WebRTC存根
library;

import 'dart:async';

bool isSecureContext() => true;
void initWebRTC() {}
Future<bool> createPeerConnection({required bool isVideo}) async => false;
Future<String?> createOffer() async => null;
Future<String?> createAnswer(String offerSdp) async => null;
Future<bool> setRemoteAnswer(String answerSdp) async => false;
void addIceCandidate(Map<String, dynamic> candidate) {}
List<String> getIceCandidates() => [];
String getConnectionState() => 'closed';
String getIceConnectionState() => 'closed';
void toggleMute(bool mute) {}
void toggleVideo(bool enabled) {}
void switchCamera() {}
void closeConnection() {}
void injectMediaElements(bool isVideo) {}
void removeMediaElements() {}
