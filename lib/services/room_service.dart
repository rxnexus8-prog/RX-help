import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import 'webrtc_service.dart';

enum RoomState {
  idle,
  hosting,       // host waiting for someone to join
  ringing,       // host received a request
  requesting,    // joiner sent request, waiting for accept
  connecting,    // WebRTC connecting
  inCall,
  rejected,
  ended,
  error,
}

class RoomService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final WebRTCService webrtc = WebRTCService();

  RoomModel? _currentRoom;
  RoomState _state = RoomState.idle;
  String? _errorMessage;
  StreamSubscription? _roomSub;
  StreamSubscription? _iceSub;
  StreamSubscription? _webrtcSub;
  Timer? _timeoutTimer;

  RoomModel? get currentRoom => _currentRoom;
  RoomState get state => _state;
  String? get errorMessage => _errorMessage;

  // ─── HOST FLOW ───────────────────────────────────────────────

  Future<String?> createRoom(UserModel user, String effectiveNumber) async {
    try {
      final code = _generateCode();

      final response = await _supabase
          .from('rooms')
          .insert({
            'room_code': code,
            'host_id': user.id,
            'host_number': effectiveNumber,
            'status': 'waiting',
          })
          .select()
          .single();

      _currentRoom = RoomModel.fromMap(response);
      _setState(RoomState.hosting);
      _listenAsHost();

      // Auto-cleanup after 5 min if no call
      _timeoutTimer = Timer(const Duration(minutes: 5), () {
        if (_state == RoomState.hosting) endCall();
      });

      return null;
    } catch (e) {
      _setError('Room creation failed');
      return e.toString();
    }
  }

  void _listenAsHost() {
    _roomSub = _supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', _currentRoom!.id)
        .listen((data) async {
          if (data.isEmpty) return;
          final room = RoomModel.fromMap(data.first);
          _currentRoom = room;

          if (room.status == 'ringing' && _state == RoomState.hosting) {
            _setState(RoomState.ringing);
          } else if (room.status == 'active' && room.answer != null) {
            await webrtc.processAnswer(room.answer!);
            _setState(RoomState.inCall);
            _listenForIceCandidates('joiner');
          } else if (room.status == 'ended') {
            _setState(RoomState.ended);
          }
        });
  }

  Future<void> acceptRequest() async {
    if (_currentRoom == null) return;
    _timeoutTimer?.cancel();

    // Init WebRTC
    await webrtc.init();
    final offer = await webrtc.createOffer(_currentRoom!.id);

    await _supabase.from('rooms').update({
      'status': 'active',
      'offer': offer,
    }).eq('id', _currentRoom!.id);

    _setState(RoomState.connecting);
    _webrtcSub = webrtc.onCallStateChange.listen((state) {
      if (state == CallState.active) _setState(RoomState.inCall);
      if (state == CallState.ended) _setState(RoomState.ended);
      notifyListeners();
    });

    _listenForIceCandidates('joiner');
  }

  Future<void> rejectRequest() async {
    if (_currentRoom == null) return;
    await _supabase.from('rooms').update({
      'status': 'waiting',
      'requester_id': null,
      'requester_number': null,
    }).eq('id', _currentRoom!.id);
    _setState(RoomState.hosting);
  }

  // ─── JOINER FLOW ─────────────────────────────────────────────

  Future<String?> joinRoom(UserModel user, String code, String effectiveNumber) async {
    try {
      final data = await _supabase
          .from('rooms')
          .select()
          .eq('room_code', code.toUpperCase())
          .eq('status', 'waiting')
          .maybeSingle();

      if (data == null) return 'Room not found or already busy';

      _currentRoom = RoomModel.fromMap(data);

      await _supabase.from('rooms').update({
        'status': 'ringing',
        'requester_id': user.id,
        'requester_number': effectiveNumber,
      }).eq('id', _currentRoom!.id);

      _setState(RoomState.requesting);
      _listenAsJoiner();

      // Timeout if not accepted in 60s
      _timeoutTimer = Timer(
        Duration(seconds: AppConfig.callTimeoutSeconds),
        () {
          if (_state == RoomState.requesting) {
            endCall();
            _setState(RoomState.ended);
          }
        },
      );

      return null;
    } catch (e) {
      return 'Failed to join: $e';
    }
  }

  void _listenAsJoiner() {
    _roomSub = _supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', _currentRoom!.id)
        .listen((data) async {
          if (data.isEmpty) return;
          final room = RoomModel.fromMap(data.first);
          _currentRoom = room;

          if (room.status == 'active' && room.offer != null && _state == RoomState.requesting) {
            _timeoutTimer?.cancel();
            // Create answer
            await webrtc.init();
            final answer = await webrtc.createAnswer(_currentRoom!.id, room.offer!);
            await _supabase.from('rooms').update({'answer': answer}).eq('id', _currentRoom!.id);
            _setState(RoomState.connecting);
            _listenForIceCandidates('host');

            _webrtcSub = webrtc.onCallStateChange.listen((state) {
              if (state == CallState.active) _setState(RoomState.inCall);
              if (state == CallState.ended) _setState(RoomState.ended);
              notifyListeners();
            });
          } else if (room.status == 'waiting' && _state == RoomState.requesting) {
            // Rejected
            _setState(RoomState.rejected);
          } else if (room.status == 'ended') {
            _setState(RoomState.ended);
          }
        });
  }

  // ─── ICE CANDIDATES ──────────────────────────────────────────

  void _listenForIceCandidates(String remoteSender) {
    _iceSub = _supabase
        .from('ice_candidates')
        .stream(primaryKey: ['id'])
        .eq('room_id', _currentRoom!.id)
        .listen((data) {
          for (final row in data) {
            if (row['sender'] == remoteSender) {
              webrtc.addIceCandidate(row['candidate']);
            }
          }
        });
  }

  // ─── CALL END ────────────────────────────────────────────────

  Future<void> endCall() async {
    _timeoutTimer?.cancel();
    _roomSub?.cancel();
    _iceSub?.cancel();
    _webrtcSub?.cancel();

    if (_currentRoom != null) {
      try {
        // Delete room and all ICE candidates (no trace left)
        await _supabase.from('rooms').delete().eq('id', _currentRoom!.id);
      } catch (_) {}
    }

    await webrtc.dispose();
    _currentRoom = null;
    _setState(RoomState.idle);
  }

  // ─── HELPERS ─────────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(AppConfig.roomCodeLength, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  void _setState(RoomState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _state = RoomState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    endCall();
    super.dispose();
  }
}
