import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/room_service.dart';
import '../../models/user_model.dart';
import 'call_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});
  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeCtrl = TextEditingController();
  bool _joining = false;
  String? _error;

  Future<void> _joinRoom() async {
    if (_codeCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter a valid 6-character code');
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

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

    final err = await room.joinRoom(user, _codeCtrl.text.trim(), effectiveNumber);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _error = err;
        _joining = false;
      });
    }
    // State changes will be handled by Consumer below
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomService>();
    final accent = Theme.of(context).colorScheme.primary;

    // Navigate to call when accepted
    if (room.state == RoomState.inCall || room.state == RoomState.connecting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CallScreen(isHost: false)),
        );
      });
    }

    return PopScope(
      onPopInvoked: (_) => room.endCall(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Join Room'),
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
          child: room.state == RoomState.requesting
              ? _Waiting(accent: accent)
              : room.state == RoomState.rejected
                  ? _Rejected(
                      onRetry: () {
                        room.endCall();
                        setState(() => _joining = false);
                      },
                    )
                  : _EnterCode(
                      ctrl: _codeCtrl,
                      error: _error,
                      joining: _joining,
                      accent: accent,
                      onJoin: _joinRoom,
                    ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }
}

class _EnterCode extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  final bool joining;
  final Color accent;
  final VoidCallback onJoin;

  const _EnterCode({
    required this.ctrl,
    this.error,
    required this.joining,
    required this.accent,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.login_rounded, color: accent, size: 56),
        const SizedBox(height: 20),
        const Text(
          'Enter Room Code',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Color(0xFFE8E8F0), fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Get the 6-character code from the caller',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 14),
        ),
        const SizedBox(height: 36),

        TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: TextStyle(
            color: accent,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: '· · · · · ·',
            hintStyle: TextStyle(
              color: accent.withOpacity(0.3),
              fontSize: 24,
              letterSpacing: 4,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4F6A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF4F6A).withOpacity(0.3)),
            ),
            child: Text(error!,
                style: const TextStyle(color: Color(0xFFFF4F6A), fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ],
        const SizedBox(height: 28),

        ElevatedButton(
          onPressed: joining ? null : onJoin,
          child: joining
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send Join Request'),
        ),
        const Spacer(),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  final Color accent;
  const _Waiting({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulse animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (_, val, child) => Transform.scale(scale: val, child: child),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFB84D).withOpacity(0.1),
              border: Border.all(
                  color: const Color(0xFFFFB84D).withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFFFFB84D), size: 44),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Waiting for host...',
          style: TextStyle(
              color: Color(0xFFE8E8F0), fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Request sent. Host will accept or reject.',
          style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: Color(0xFFFFB84D),
            strokeWidth: 2,
          ),
        ),
      ],
    );
  }
}

class _Rejected extends StatelessWidget {
  final VoidCallback onRetry;
  const _Rejected({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF4F6A).withOpacity(0.1),
          ),
          child: const Icon(Icons.call_end_rounded,
              color: Color(0xFFFF4F6A), size: 40),
        ),
        const SizedBox(height: 20),
        const Text(
          'Request Rejected',
          style: TextStyle(
              color: Color(0xFFE8E8F0), fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'The host did not accept your call.',
          style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 14),
        ),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
      ],
    );
  }
}
