import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<Account?> register(String name, String email, String password) async {
    try {
      // 1. Create authentication account
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        return null;
      }

      // 2. Insert profile information
      final profile = await supabase
          .from('profiles')
          .insert({'id': user.id, 'name': name, 'email': email, 'role': 'user'})
          .select()
          .single();

      // 3. Return Account object

      return Account.fromJson(profile);
    } catch (e) {
      print("Register error: $e");

      return null;
    }
  }

  Future<Account?> loginValidate(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        return null;
      }

      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return Account.fromJson(profile);
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }
}
