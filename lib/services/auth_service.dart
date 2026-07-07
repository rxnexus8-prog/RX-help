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
    if (userId != null) await _loadUser(userId);
  }

  String _generateUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<String?> register({
    required String callNumber,
    required String password,
    required String displayName,
  }) async {
    if (callNumber.length != AppConfig.callNumberLength) {
      return 'Number must be exactly ${AppConfig.callNumberLength} digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(callNumber)) return 'Only digits allowed';
    if (password.length < 6) return 'Password min 6 characters';
    if (displayName.trim().isEmpty) return 'Display name required';

    _isLoading = true;
    notifyListeners();

    try {
      final passwordHash = _hashPassword(password);
      String uid = _generateUid();

      // Ensure unique uid
      while (true) {
        final existing = await _supabase
            .from('users')
            .select('id')
            .eq('unique_uid', uid)
            .maybeSingle();
        if (existing == null) break;
        uid = _generateUid();
      }

      final response = await _supabase.from('users').insert({
        'call_number': callNumber,
        'password_hash': passwordHash,
        'use_random_number': false,
        'show_as_unknown': false,
        'display_name': displayName.trim(),
        'unique_uid': uid,
        'is_online': false,
      }).select().single();

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
      if (response == null) return 'Invalid number or password';
      _currentUser = UserModel.fromMap(response);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _currentUser!.id);
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      return 'Login failed: ${e.message}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUser(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      _currentUser = UserModel.fromMap(response);
      notifyListeners();
    } catch (_) {}
  }


  Future<String?> updateSettings({
    String? newCallNumber,
    bool? useRandomNumber,
    bool? showAsUnknown,
  }) async {
    if (newCallNumber != null) {
      if (newCallNumber.length != AppConfig.callNumberLength)
        return "Number must be exactly ${AppConfig.callNumberLength} digits";
    }
    _isLoading = true; notifyListeners();
    try {
      final Map<String,dynamic> u = {};
      if (newCallNumber != null) u["call_number"] = newCallNumber;
      if (useRandomNumber != null) u["use_random_number"] = useRandomNumber;
      if (showAsUnknown != null) u["show_as_unknown"] = showAsUnknown;
      if (u.isEmpty) return null;
      _currentUser = UserModel(
      );
      notifyListeners(); return null;
    } on PostgrestException catch(e) {
      if(e.code=="23505") return "This number is already taken";
      return "Update failed: ${e.message}";
    } finally { _isLoading=false; notifyListeners(); }
  }

  Future<String?> updateDisplayName(String newName) async {
    if (newName.trim().isEmpty) return 'Name cannot be empty';
    try {
      await _supabase.from('users')
          .update({'display_name': newName.trim()})
          .eq('id', _currentUser!.id);
      _currentUser = _currentUser!.copyWith(displayName: newName.trim());
      notifyListeners();
      return null;
    } catch (e) {
      return 'Update failed';
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final res = await _supabase
        .from('users')
        .select('id, display_name, unique_uid, call_number, is_online')
        .or('display_name.ilike.%$q%,unique_uid.eq.$q')
        .neq('id', _currentUser!.id)
        .limit(20);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> logout() async {
    await _supabase.from('users').update({'is_online': false}).eq('id', _currentUser!.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    _currentUser = null;
    notifyListeners();
  }
}

  String generateRandomNumber() {
    const chars = '0123456789';
    final rand = Random.secure();
    return List.generate(AppConfig.callNumberLength, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String?> updateSettings({
    String? newCallNumber,
    bool? useRandomNumber,
    bool? showAsUnknown,
  }) async {
    if (newCallNumber != null) {
      if (newCallNumber.length != AppConfig.callNumberLength) {
        return 'Number must be exactly ${AppConfig.callNumberLength} digits';
      }
      if (newCallNumber.contains(RegExp(r'[^0-9]'))) return 'Only digits allowed';
    }
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> u = {};
      if (newCallNumber != null) u['call_number'] = newCallNumber;
      if (useRandomNumber != null) u['use_random_number'] = useRandomNumber;
      if (showAsUnknown != null) u['show_as_unknown'] = showAsUnknown;
      if (u.isEmpty) { _isLoading = false; notifyListeners(); return null; }
      await _supabase.from('users').update(u).eq('id', _currentUser!.id);
      _currentUser = _currentUser!.copyWith(
        callNumber: newCallNumber,
        useRandomNumber: useRandomNumber,
        showAsUnknown: showAsUnknown,
      );
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'This number is already taken';
      return 'Update failed: ${e.message}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }