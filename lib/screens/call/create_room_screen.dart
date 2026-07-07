import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../models/user_model.dart';
import 'call_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  bool _created = false;

  @override
  void initState() {
    super.initState();
    _createRoom();
  }

  Future<void> _createRoom() async {
    final auth = context.read<AuthService>();
    final room = context.read<RoomService>();
    final user = auth.currentUser!;

    String effectiveNumber;
    if (user.showAsUnknown) {
      effectiveNumber = 'Unknown';
    } else if (user.useRandomNumber) {
      effectiveNumber = auth.generateRandomNumber();
      effectiveNumber = UserModel.maskNumber(effectiveNumber);
    } else {
      effectiveNumber = UserModel.maskNumber(user.callNumber);
    }

    final err = await room.createRoom(user, effectiveNumber);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      Navigator.pop(context);
      return;
    }
    if (mounted) setState(() => _created = true);
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomService>();
    final accent = Theme.of(context).colorScheme.primary;

    // Navigate to call when accepted
    if (room.state == RoomState.inCall || room.state == RoomState.connecting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CallScreen(isHost: true)),
        );
      });
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (_) => room.endCall(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Room'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              room.endCall();
              Navigator.pop(context);
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: !_created
              ? const Center(child: CircularProgressIndicator())
              : room.state == RoomState.ringing
                  ? _IncomingRequest(room: room, accent: accent)
                  : _WaitingForRequest(room: room, accent: accent),
        ),
      ),
    );
  }
}

class _WaitingForRequest extends StatelessWidget {
  final RoomService room;
  final Color accent;
  const _WaitingForRequest({required this.room, required this.accent});

  @override
  Widget build(BuildContext context) {
    final code = room.currentRoom?.roomCode ?? '...';
    return Column(
      children: [
        const Spacer(),
        // Pulsing circle
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(seconds: 2),
          curve: Curves.easeInOut,
          builder: (_, val, child) => Transform.scale(scale: val, child: child),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.1),
              border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(Icons.radar_rounded, color: accent, size: 48),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Waiting for someone to join...',
          style: TextStyle(color: Color(0xFFE8E8F0), fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Share the room code below',
          style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 14),
        ),
        const SizedBox(height: 36),

        // Room code display
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF141420),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              const Text(
                'ROOM CODE',
                style: TextStyle(
                  color: Color(0xFF5C5C7A),
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                code,
                style: TextStyle(
                  color: accent,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: _CodeButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CodeButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () => Share.share('Join my GhostCall! Code: $code'),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _IncomingRequest extends StatelessWidget {
  final RoomService room;
  final Color accent;
  const _IncomingRequest({required this.room, required this.accent});

  @override
  Widget build(BuildContext context) {
    final requester = room.currentRoom?.requesterNumber ?? 'Unknown';
    return Column(
      children: [
        const Spacer(),
        // Ring animation
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4CAF85).withOpacity(0.12),
            border: Border.all(
                color: const Color(0xFF4CAF85).withOpacity(0.4), width: 1.5),
          ),
          child: const Icon(Icons.call_received_rounded,
              color: Color(0xFF4CAF85), size: 48),
        ),
        const SizedBox(height: 28),
        const Text(
          'Incoming Request!',
          style: TextStyle(
            color: Color(0xFFE8E8F0),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Caller', style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          requester,
          style: const TextStyle(
            color: Color(0xFFE8E8F0),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 40),

        // Accept / Reject
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CallButton(
              icon: Icons.call_end_rounded,
              color: const Color(0xFFFF4F6A),
              label: 'Reject',
              onTap: () => room.rejectRequest(),
            ),
            const SizedBox(width: 40),
            _CallButton(
              icon: Icons.call_rounded,
              color: const Color(0xFF4CAF85),
              label: 'Accept',
              onTap: () => room.acceptRequest(),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}

class _CodeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CodeButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE8E8F0), size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFFE8E8F0),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _CallButton(
      {required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 20)],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Color(0xFF5C5C7A), fontSize: 13)),
      ],
    );
  }
}
