import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum CallState { idle, connecting, active, ended }

class WebRTCService {
  final _supabase = Supabase.instance.client;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _roomId;
  bool _isCaller = false;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  CallState callState = CallState.idle;

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  final _callStateController = StreamController<CallState>.broadcast();
  Stream<CallState> get onCallStateChange => _callStateController.stream;

  static const _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ]
  };

  Future<void> init() async {
    _peerConnection = await createPeerConnection(_config);

    _peerConnection!.onIceCandidate = (candidate) async {
      if (_roomId == null) return;
      await _supabase.from('ice_candidates').insert({
        'room_id': _roomId,
        'sender': _isCaller ? 'host' : 'joiner',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        callState = CallState.active;
        _callStateController.add(CallState.active);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        callState = CallState.ended;
        _callStateController.add(CallState.ended);
      }
    };

    await _getLocalStream();
  }

  Future<void> _getLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
  }

  /// HOST: Create WebRTC offer
  Future<Map<String, dynamic>> createOffer(String roomId) async {
    _roomId = roomId;
    _isCaller = true;

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    return {'type': offer.type, 'sdp': offer.sdp};
  }

  /// JOINER: Process offer and create answer
  Future<Map<String, dynamic>> createAnswer(
      String roomId, Map<String, dynamic> offerData) async {
    _roomId = roomId;
    _isCaller = false;

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offerData['sdp'], offerData['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    return {'type': answer.type, 'sdp': answer.sdp};
  }

  /// HOST: Process answer from joiner
  Future<void> processAnswer(Map<String, dynamic> answerData) async {
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answerData['sdp'], answerData['type']),
    );
  }

  /// Add ICE candidate from remote
  Future<void> addIceCandidate(Map<String, dynamic> candidateData) async {
    try {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        ),
      );
    } catch (_) {}
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  Future<void> dispose() async {
    callState = CallState.ended;
    _callStateController.add(CallState.ended);
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _roomId = null;
  }

  Future<void> close() async {
    await dispose();
    await _callStateController.close();
  }
}
