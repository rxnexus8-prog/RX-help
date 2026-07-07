import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/room_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => RoomService()),
        Provider<SharedPreferences>.value(value: prefs),
      ],
      child: const GhostCallApp(),
    ),
  );
}

class GhostCallApp extends StatelessWidget {
  const GhostCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<SharedPreferences>();
    final appName = prefs.getString('app_display_name') ?? 'R4X Help';
    final accentHex = prefs.getInt('accent_color') ?? 0xFF6C63FF;

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Color(accentHex)),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: const Color(0xFF2D2D4A),
        surface: const Color(0xFF141420),
        onPrimary: Colors.white,
        onSurface: const Color(0xFFE8E8F0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A0F),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFFE8E8F0)),
        titleTextStyle: TextStyle(
          color: Color(0xFFE8E8F0),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4F6A), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF5C5C7A), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF3D3D5C), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF141420),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }
}
