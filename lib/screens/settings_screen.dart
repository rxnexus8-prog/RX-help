import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _numberCtrl = TextEditingController();
  final _appNameCtrl = TextEditingController();
  bool _showChangeNumber = false;
  String? _msg;
  bool _isError = false;

  static const _accentColors = [
    {'name': 'Violet', 'color': Color(0xFF6C63FF)},
    {'name': 'Cyan', 'color': Color(0xFF00BCD4)},
    {'name': 'Green', 'color': Color(0xFF4CAF85)},
    {'name': 'Pink', 'color': Color(0xFFE91E8C)},
    {'name': 'Orange', 'color': Color(0xFFFF6D3F)},
    {'name': 'Gold', 'color': Color(0xFFFFB84D)},
  ];

  @override
  void initState() {
    super.initState();
    final prefs = context.read<SharedPreferences>();
    _appNameCtrl.text = prefs.getString('app_display_name') ?? 'GhostCall';
  }

  void _showMsg(String text, {bool error = false}) {
    setState(() {
      _msg = text;
      _isError = error;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  Future<void> _saveAppName() async {
    final prefs = context.read<SharedPreferences>();
    await prefs.setString('app_display_name', _appNameCtrl.text.trim());
    _showMsg('App name updated!');
  }

  Future<void> _setAccentColor(Color color) async {
    final prefs = context.read<SharedPreferences>();
    await prefs.setInt('accent_color', color.value);
    setState(() {});
  }

  Future<void> _changeNumber() async {
    final auth = context.read<AuthService>();
    final err = await auth.updateSettings(newCallNumber: _numberCtrl.text.trim());
    if (err != null) {
      _showMsg(err, error: true);
    } else {
      _showMsg('Number updated!');
      setState(() => _showChangeNumber = false);
      _numberCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final prefs = context.watch<SharedPreferences>();
    final user = auth.currentUser!;
    final accent = Theme.of(context).colorScheme.primary;
    final currentAccent = Color(prefs.getInt('accent_color') ?? 0xFF6C63FF);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current identity card
          _SectionHeader('Your Identity'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_outline_rounded, color: accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Call Number',
                                style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              UserModel.maskNumber(user.callNumber),
                              style: TextStyle(
                                color: accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showChangeNumber = !_showChangeNumber),
                        child: Text(_showChangeNumber ? 'Cancel' : 'Change'),
                      ),
                    ],
                  ),
                  if (_showChangeNumber) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _numberCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 20,
                      style: const TextStyle(
                          color: Color(0xFFE8E8F0), letterSpacing: 1.5),
                      decoration: const InputDecoration(
                        labelText: 'New 20-digit Number',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _changeNumber,
                        child: const Text('Save Number'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Privacy toggles
          _SectionHeader('Call Privacy'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: user.useRandomNumber,
                  onChanged: (val) =>
                      auth.updateSettings(useRandomNumber: val),
                  title: const Text('Random Number Each Call',
                      style: TextStyle(color: Color(0xFFE8E8F0), fontSize: 14)),
                  subtitle: const Text(
                      'New random number shown per call',
                      style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12)),
                  activeColor: accent,
                ),
                const Divider(color: Color(0xFF2D2D4A), height: 0),
                SwitchListTile(
                  value: user.showAsUnknown,
                  onChanged: (val) =>
                      auth.updateSettings(showAsUnknown: val),
                  title: const Text('Show as Unknown',
                      style: TextStyle(color: Color(0xFFE8E8F0), fontSize: 14)),
                  subtitle: const Text(
                      'Others see "Unknown" instead of your number',
                      style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12)),
                  activeColor: accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // App Customization
          _SectionHeader('App Customization'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App Display Name',
                      style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _appNameCtrl,
                          style: const TextStyle(color: Color(0xFFE8E8F0)),
                          decoration: const InputDecoration(
                            hintText: 'e.g. PrivCall, SecureVoice...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _saveAppName,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Accent Color',
                      style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _accentColors.map((item) {
                      final c = item['color'] as Color;
                      final isSelected = c.value == currentAccent.value;
                      return GestureDetector(
                        onTap: () => _setAccentColor(c),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 10)]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['name'] as String,
                              style: const TextStyle(
                                  color: Color(0xFF5C5C7A), fontSize: 10),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // App info
          _SectionHeader('About'),
          Card(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(icon: Icons.history_toggle_off_rounded,
                      label: 'Call History', value: 'Never saved'),
                  Divider(color: Color(0xFF2D2D4A), height: 20),
                  _InfoRow(icon: Icons.fiber_manual_record_outlined,
                      label: 'Recording', value: 'Disabled'),
                  Divider(color: Color(0xFF2D2D4A), height: 20),
                  _InfoRow(icon: Icons.share_outlined,
                      label: 'Data Sharing', value: 'None'),
                  Divider(color: Color(0xFF2D2D4A), height: 20),
                  _InfoRow(icon: Icons.security_rounded,
                      label: 'Transport', value: 'P2P WebRTC'),
                ],
              ),
            ),
          ),

          if (_msg != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isError
                    ? const Color(0xFFFF4F6A).withOpacity(0.1)
                    : const Color(0xFF4CAF85).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isError
                      ? const Color(0xFFFF4F6A).withOpacity(0.3)
                      : const Color(0xFF4CAF85).withOpacity(0.3),
                ),
              ),
              child: Text(
                _msg!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isError
                      ? const Color(0xFFFF4F6A)
                      : const Color(0xFF4CAF85),
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _appNameCtrl.dispose();
    super.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF5C5C7A),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF85), size: 18),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(color: Color(0xFFE8E8F0), fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(color: Color(0xFF5C5C7A), fontSize: 13)),
      ],
    );
  }
}
