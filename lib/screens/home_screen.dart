import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'call/create_room_screen.dart';
import 'call/join_room_screen.dart';
import 'settings_screen.dart';
import 'auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser!;
    final accent = Theme.of(context).colorScheme.primary;

    String displayNumber;
    if (user.showAsUnknown) {
      displayNumber = 'Unknown';
    } else {
      displayNumber = UserModel.maskNumber(user.callNumber);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GhostCall'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Identity card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.15),
                    const Color(0xFF141420),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.25), width: 1),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline_rounded, color: accent, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your Call Number',
                    style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayNumber,
                    style: TextStyle(
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (user.useRandomNumber) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB84D).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Random number each call',
                        style: TextStyle(color: Color(0xFFFFB84D), fontSize: 11),
                      ),
                    ),
                  ],
                  if (user.showAsUnknown) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF85).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Showing as Unknown',
                        style: TextStyle(color: Color(0xFF4CAF85), fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Privacy badges row
            Row(
              children: [
                _badge(Icons.history_toggle_off_rounded, 'No History'),
                const SizedBox(width: 10),
                _badge(Icons.fiber_manual_record_outlined, 'No Recording'),
                const SizedBox(width: 10),
                _badge(Icons.lock_outline_rounded, 'P2P'),
              ],
            ),
            const SizedBox(height: 40),

            // Main buttons
            _ActionCard(
              icon: Icons.add_call,
              title: 'Create Room',
              subtitle: 'Start a call — share the code',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _ActionCard(
              icon: Icons.call_received_rounded,
              title: 'Join Room',
              subtitle: 'Enter a code to request a call',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
              ),
            ),
            const Spacer(),

            // Logout
            TextButton.icon(
              onPressed: () async {
                await context.read<AuthService>().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF5C5C7A)),
              label: const Text(
                'Sign out',
                style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141420),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4CAF85), size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF5C5C7A), fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF141420),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D2D4A)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE8E8F0),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF5C5C7A), fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF3D3D5C)),
          ],
        ),
      ),
    );
  }
}
