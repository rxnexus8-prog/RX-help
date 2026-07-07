import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      await _loadUser(userId);
    }
  }

  Future<String?> register({
    required String callNumber,
    required String password,
  }) async {
    if (callNumber.length != AppConfig.callNumberLength) {
      return 'Number must be exactly ${AppConfig.callNumberLength} digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(callNumber)) {
      return 'Only digits allowed';
    }
    if (password.length < 6) {
      return 'Password min 6 characters';
    }

    _isLoading = true;
    notifyListeners();

    try {
      final passwordHash = _hashPassword(password);

      final response = await _supabase
          .from('users')
          .insert({
            'call_number': callNumber,
            'password_hash': passwordHash,
            'use_random_number': false,
            'show_as_unknown': false,
          })
          .select()
          .single();

      _currentUser = UserModel.fromMap(response);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _currentUser!.id);
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'This number is already taken';
      return 'Registration failed: ${e.message}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> login({
    required String callNumber,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final passwordHash = _hashPassword(password);

      final response = await _supabase
          .from('users')
          .select()
          .eq('call_number', callNumber)
          .eq('password_hash', passwordHash)
          .maybeSingle();

      if (response == null) return 'Wrong number or password';

      _currentUser = UserModel.fromMap(response);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _currentUser!.id);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Login failed. Try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    notifyListeners();
  }

  Future<String?> updateSettings({
    String? newCallNumber,
    bool? useRandomNumber,
    bool? showAsUnknown,
  }) async {
    if (_currentUser == null) return 'Not logged in';

    final updates = <String, dynamic>{};
    if (newCallNumber != null) {
      if (newCallNumber.length != AppConfig.callNumberLength) {
        return 'Number must be ${AppConfig.callNumberLength} digits';
      }
      updates['call_number'] = newCallNumber;
    }
    if (useRandomNumber != null) updates['use_random_number'] = useRandomNumber;
    if (showAsUnknown != null) updates['show_as_unknown'] = showAsUnknown;

    try {
      final response = await _supabase
          .from('users')
          .update(updates)
          .eq('id', _currentUser!.id)
          .select()
          .single();

      _currentUser = UserModel.fromMap(response);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Update failed: $e';
    }
  }

  Future<void> _loadUser(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        _currentUser = UserModel.fromMap(response);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Generate random 20-digit number for calls
  String generateRandomNumber() {
    final rand = Random.secure();
    return List.generate(AppConfig.callNumberLength, (_) => rand.nextInt(10))
        .join();
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }
}
