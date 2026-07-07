import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/room_service.dart';

class CallScreen extends StatefulWidget {
  final bool isHost;
  const CallScreen({super.key, required this.isHost});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late Timer _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speaker = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });

    // Listen for call ending
    final room = context.read<RoomService>();
    room.addListener(_checkCallEnded);
  }

  void _checkCallEnded() {
    final room = context.read<RoomService>();
    if (room.state == RoomState.ended || room.state == RoomState.idle) {
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _endCall() async {
    final room = context.read<RoomService>();
    await room.endCall();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomService>();
    final accent = Theme.of(context).colorScheme.primary;
    final otherNumber = widget.isHost
        ? (room.currentRoom?.requesterNumber ?? 'Unknown')
        : (room.currentRoom?.hostNumber ?? 'Unknown');

    final isConnecting = room.state == RoomState.connecting;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF07070D),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              children: [
                // Status bar top
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConnecting
                            ? const Color(0xFFFFB84D).withOpacity(0.15)
                            : const Color(0xFF4CAF85).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isConnecting
                                ? Icons.signal_wifi_connected_no_internet_4_rounded
                                : Icons.lock_rounded,
                            color: isConnecting
                                ? const Color(0xFFFFB84D)
                                : const Color(0xFF4CAF85),
                            size: 12,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isConnecting ? 'Connecting...' : 'Encrypted P2P',
                            style: TextStyle(
                              color: isConnecting
                                  ? const Color(0xFFFFB84D)
                                  : const Color(0xFF4CAF85),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isConnecting)
                      Text(
                        _formatTime(_seconds),
                        style: const TextStyle(
                            color: Color(0xFF5C5C7A), fontSize: 14, fontFamily: 'monospace'),
                      ),
                  ],
                ),

                const Spacer(),

                // Caller identity
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.1),
                    border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(Icons.person_outline_rounded, color: accent, size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Call Number',
                  style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  otherNumber,
                  style: const TextStyle(
                    color: Color(0xFFE8E8F0),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isConnecting ? 'Connecting...' : 'On call',
                  style: TextStyle(
                    color: isConnecting
                        ? const Color(0xFFFFB84D)
                        : const Color(0xFF4CAF85),
                    fontSize: 14,
                  ),
                ),

                const Spacer(),

                // No recording badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141420),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_manual_record_outlined,
                          color: Color(0xFF4CAF85), size: 12),
                      SizedBox(width: 6),
                      Text(
                        'Not recorded · No history saved',
                        style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlBtn(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _muted ? 'Unmute' : 'Mute',
                      active: _muted,
                      onTap: () {
                        setState(() => _muted = !_muted);
                        room.webrtc.toggleMute();
                      },
                    ),
                    const SizedBox(width: 20),

                    // End call
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4F6A),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFFF4F6A).withOpacity(0.4),
                                    blurRadius: 20),
                              ],
                            ),
                            child: const Icon(Icons.call_end_rounded,
                                color: Colors.white, size: 32),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('End',
                            style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 20),

                    _ControlBtn(
                      icon: _speaker
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: 'Speaker',
                      active: _speaker,
                      onTap: () {
                        setState(() => _speaker = !_speaker);
                        room.webrtc.toggleSpeaker();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _timer.cancel();
    context.read<RoomService>().removeListener(_checkCallEnded);
    super.dispose();
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? const Color(0xFF6C63FF).withOpacity(0.2)
                  : const Color(0xFF1A1A2E),
              border: Border.all(
                color: active
                    ? const Color(0xFF6C63FF).withOpacity(0.5)
                    : const Color(0xFF2D2D4A),
              ),
            ),
            child: Icon(icon,
                color: active
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFFE8E8F0),
                size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Color(0xFF5C5C7A), fontSize: 11)),
      ],
    );
  }
}
