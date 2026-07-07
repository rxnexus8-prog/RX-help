import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _numberCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  void _generateNumber() {
    final rand = Random.secure();
    final num = List.generate(20, (_) => rand.nextInt(10)).join();
    _numberCtrl.text = num;
    setState(() {});
  }

  Future<void> _register() async {
    setState(() => _error = null);
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    final auth = context.read<AuthService>();
    final err = await auth.register(
      callNumber: _numberCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final auth = context.watch<AuthService>();
    final numberLen = _numberCtrl.text.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Call Number',
                      style: TextStyle(
                        color: Color(0xFFE8E8F0),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'This is your identity. No real name or phone needed. '
                      'Choose any 20-digit number, or generate a random one.',
                      style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Number field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numberCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 20,
                      style: const TextStyle(
                        color: Color(0xFFE8E8F0),
                        letterSpacing: 1.5,
                        fontSize: 15,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: '20-digit Number',
                        counterText: '$numberLen/20',
                        counterStyle: TextStyle(
                          color: numberLen == 20
                              ? const Color(0xFF4CAF85)
                              : const Color(0xFF5C5C7A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _generateNumber,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.casino_outlined, color: accent, size: 22),
                    ),
                  ),
                ],
              ),

              // Preview masked number
              if (_numberCtrl.text.length == 20) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141420),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_outlined,
                          color: Color(0xFF5C5C7A), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Callers see: ${_maskNumber(_numberCtrl.text)}',
                        style: const TextStyle(
                          color: Color(0xFF5C5C7A),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: Color(0xFFE8E8F0)),
                decoration: InputDecoration(
                  labelText: 'Password (min 6 chars)',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF5C5C7A)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF5C5C7A),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: Color(0xFFE8E8F0)),
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: Color(0xFF5C5C7A)),
                ),
                onSubmitted: (_) => _register(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4F6A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF4F6A).withOpacity(0.3)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFFF4F6A), fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: auth.isLoading ? null : _register,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 24),

              // Warning about number
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFFB84D), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save your number and password. No recovery option — total privacy means no email link.',
                      style: TextStyle(
                          color: Color(0xFF5C5C7A), fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _maskNumber(String n) {
    if (n.length <= 6) return n;
    return '${n.substring(0, 3)}${'*' * (n.length - 6)}${n.substring(n.length - 3)}';
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}
