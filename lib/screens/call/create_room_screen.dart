import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/room_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'call_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  bool _creating = true;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _createRoom());
  }

  Future<void> _createRoom() async {
    final auth = context.read<AuthService>();
    final room = context.read<RoomService>();
    final user = auth.currentUser!;

    String effectiveNumber;
    if (user.showAsUnknown) {
      effectiveNumber = 'Unknown';
    } else if (user.useRandomNumber) {
      effectiveNumber = UserModel.maskNumber(auth.generateRandomNumber());
    } else {
      effectiveNumber = UserModel.maskNumber(user.callNumber);
    }

    await room.createRoom(user, effectiveNumber);
    if (mounted) setState(() => _creating = false);
  }

  void _showAcceptDialog(String callerNumber) {
    if (_dialogShown) return;
    _dialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141420),
        title: const Text('Incoming Request',
            style: TextStyle(color: Colors.white)),
        content: Text('From: $callerNumber',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _dialogShown = false;
              await context.read<RoomService>().rejectRequest();
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<RoomService>().acceptRequest();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomService>();
    final accent = Theme.of(context).colorScheme.primary;

    // State machine navigation
    if (room.state == RoomState.ringing && !_dialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAcceptDialog(room.currentRoom?.requesterNumber ?? 'Unknown');
      });
    }

    if (room.state == RoomState.connecting || room.state == RoomState.inCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const CallScreen(isHost: true)));
        }
      });
    }

    if (room.state == RoomState.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }

    final code = room.currentRoom?.roomCode;

    return PopScope(
      canPop: true,
      onPopInvoked: (_) => room.endCall(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Room'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              room.endCall();
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(
          child: _creating || code == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Share this code:',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 20),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accent.withOpacity(0.4)),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            color: accent,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Tap code to copy',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 24),
                    const Text('Waiting for someone to join...',
                        style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ),
        ),
      ),
    );
  }
}
