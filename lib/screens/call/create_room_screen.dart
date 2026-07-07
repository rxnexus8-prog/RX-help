import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/room_service.dart';
import '../../services/auth_service.dart';
import 'call_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  String? _roomCode;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _createRoom();
  }

  Future<void> _createRoom() async {
    final auth = context.read<AuthService>();
    final room = context.read<RoomService>();
    final code = await room.createRoom(auth.currentUser!);
    if (!mounted) return;
    setState(() { _roomCode = code; _loading = false; });
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final room = context.read<RoomService>();
      final status = await room.checkRoomStatus(_roomCode!);
      if (status == 'ringing' && mounted) {
        _pollTimer?.cancel();
        final auth = context.read<AuthService>();
        final requester = await room.getRequesterNumber(_roomCode!);
        _showAcceptDialog(requester ?? 'Unknown');
      }
    });
  }

  void _showAcceptDialog(String callerNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141420),
        title: const Text('Incoming Request', style: TextStyle(color: Colors.white)),
        content: Text('From: $callerNumber', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final room = context.read<RoomService>();
              await room.rejectRequest(_roomCode!);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final room = context.read<RoomService>();
              await room.acceptRequest(_roomCode!);
              if (!mounted) return;
              final auth = context.read<AuthService>();
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => CallScreen(
                  roomCode: _roomCode!,
                  isHost: true,
                  localUser: auth.currentUser!,
                  remoteNumber: callerNumber,
                ),
              ));
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room'), leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      )),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share this code:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.4)),
                    ),
                    child: Text(_roomCode!, style: TextStyle(
                      color: accent, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8,
                    )),
                  ),
                  const SizedBox(height: 24),
                  const Text('Waiting for someone to join...', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(),
                ],
              ),
      ),
    );
  }
}
