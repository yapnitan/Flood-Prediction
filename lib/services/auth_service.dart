import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';

/// Deep-link scheme the app registers so Supabase's password-reset email
/// can open the app again and hand back a recovery session.
/// Must match:
///  - Supabase Dashboard > Authentication > URL Configuration > Redirect URLs
///  - android/app/src/main/AndroidManifest.xml intent-filter
///  - ios/Runner/Info.plist CFBundleURLTypes
const String kPasswordResetRedirect =
    'https://public-flutter.web.app/reset-callback';

/// Result of a login attempt. [account] is non-null only on success;
/// [error] gives a user-facing reason when it fails (wrong password,
/// disabled account, pending approval, etc.) so the UI can show something
/// more useful than a generic "invalid credentials" message.
class LoginResult {
  final Account? account;
  final String? error;

  LoginResult.success(this.account) : error = null;
  LoginResult.failure(this.error) : account = null;
}

class AuthService {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      // 1. Create authentication account
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // stores name in user_metadata
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

  /// Signs in with Supabase auth, then checks the matching `account` row.
  /// Both [Account.isActive] (admin on/off switch) and [Account.status]
  /// (approval workflow) must pass for login to succeed; either failing
  /// signs the auth session back out so the user isn't left half-logged-in.
  Future<LoginResult> loginValidate(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return LoginResult.failure('Invalid email or password');
      }

      // Try to fetch existing profile
      final existing = await supabase
          .from('account')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      Account account;
      if (existing != null) {
        account = Account.fromJson(existing);
      } else {
        // No profile yet (first login after email confirmation) — create it now
        final inserted = await supabase
            .from('account')
            .insert({
              'id': user.id,
              'name': user.userMetadata?['name'] ?? '',
              'email': user.email,
              'role': 'user',
            })
            .select()
            .single();
        account = Account.fromJson(inserted);
      }

      if (!account.isActive) {
        await supabase.auth.signOut();
        return LoginResult.failure(
          'Your account has been disabled. Please contact an administrator.',
        );
      }
      if (account.status == 'pending') {
        await supabase.auth.signOut();
        return LoginResult.failure('Your account is still pending admin approval.');
      }
      if (account.status == 'rejected') {
        await supabase.auth.signOut();
        return LoginResult.failure('Your account application was rejected.');
      }

      return LoginResult.success(account);
    } catch (e) {
      debugPrint("Login error: $e");
      return LoginResult.failure('Invalid email or password');
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  /// Looks up the `account` row by its id (== the Supabase auth user id).
  Future<Account?> getAccountById(String id) async {
    try {
      final row = await supabase
          .from('account')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row != null ? Account.fromJson(row) : null;
    } catch (e) {
      debugPrint('AuthService.getAccountById error: $e');
      return null;
    }
  }

  /// Step 1 of "forgot password": emails the user a recovery link that
  /// deep-links back into the app via [kPasswordResetRedirect]. Opening
  /// that link fires an `AuthChangeEvent.passwordRecovery` event (handled
  /// in main.dart), which is what actually lets [updatePassword] succeed.
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kPasswordResetRedirect,
      );
      return {
        'status': 'success',
        'message':
            'If an account exists for that email, a reset link has been sent. Please check your inbox.',
      };
    } catch (e) {
      debugPrint('AuthService.sendPasswordResetEmail error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Step 2 of "forgot password": must be called while the temporary
  /// recovery session from the emailed link is active (i.e. from
  /// ResetPasswordView, right after the passwordRecovery event fires).
  Future<Map<String, dynamic>> updatePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      return {'status': 'success', 'message': 'Password updated successfully.'};
    } catch (e) {
      debugPrint('AuthService.updatePassword error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<bool> updateProfile({required String id, required String name}) async {
    try {
      await supabase.from('account').update({'name': name}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('AuthService.updateProfile error: $e');
      return false;
    }
  }

  Future<bool> updateNotificationPrefs({
    required String id,
    required bool notifyEmail,
    required bool notifyPush,
  }) async {
    try {
      await supabase.from('account').update({
        'notify_email': notifyEmail,
        'notify_push': notifyPush,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('AuthService.updateNotificationPrefs error: $e');
      return false;
    }
  }
}
