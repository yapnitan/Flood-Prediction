import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      // 1. Create authentication account
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // 👈 ADD THIS LINE — stores name in user_metadata
      );

      final user = response.user;

      if (user == null) {
        return {'status': 'error', 'message': 'Registration failed'};
      }

      // 2. Check if a session exists (it won't if email confirmation is required)
      if (response.session == null) {
        return {
          'status': 'confirm_email',
          'message': 'Please check your email to confirm your account before logging in.',
        };
      }

      // 3. Session exists (auto-confirmed) — safe to insert profile now
      final account = await supabase
          .from('account')
          .insert({'id': user.id, 'name': name, 'email': email, 'role': 'user'})
          .select()
          .single();

      return {'status': 'success', 'account': Account.fromJson(account)};
    } catch (e) {
      debugPrint("Register error: $e");
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Account?> loginValidate(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) return null;

      // Try to fetch existing profile
      final existing = await supabase
          .from('account')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        return Account.fromJson(existing);
      }

      // No profile yet (first login after email confirmation) — create it now
      // Note: you'll need to also store 'name' somewhere accessible,
      // e.g. in user.userMetadata during signUp — see note below
      final account = await supabase
          .from('account')
          .insert({
            'id': user.id,
            'name': user.userMetadata?['name'] ?? '',
            'email': user.email,
            'role': 'user',
          })
          .select()
          .single();

      return Account.fromJson(account);
    } catch (e) {
      debugPrint("Login error: $e");
      return null;
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}
