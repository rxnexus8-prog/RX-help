import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _numberCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    setState(() => _error = null);
    final auth = context.read<AuthService>();
    final err = await auth.login(
      callNumber: _numberCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              // Logo
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(Icons.call_rounded, color: accent, size: 32),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFE8E8F0),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Login with your call number',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Number field
              TextField(
                controller: _numberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 20,
                style: const TextStyle(color: Color(0xFFE8E8F0), letterSpacing: 2),
                decoration: const InputDecoration(
                  labelText: '20-digit Call Number',
                  prefixIcon: Icon(Icons.tag_rounded, color: Color(0xFF5C5C7A)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),

              // Password field
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: Color(0xFFE8E8F0)),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF5C5C7A)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF5C5C7A),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _login(),
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
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFF4F6A), fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: auth.isLoading ? null : _login,
                child: auth.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 20),

              // Privacy badge
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141420),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF4CAF85), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No phone number, no email needed. Total privacy.',
                        style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have a number? ",
                    style: TextStyle(color: Color(0xFF5C5C7A), fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(
                      'Create one',
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  @override
  void dispose() {
    _numberCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
