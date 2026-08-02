import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';

const String _avatarBucket = 'avatars';

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
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      final user = response.user;

      if (user == null) {
        return {'status': 'error', 'message': 'Registration failed'};
      }

      if (response.session == null) {
        return {
          'status': 'confirm_email',
          'message': 'Please check your email to confirm your account before logging in.',
          'email': email,
        };
      }

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

      final existing = await supabase
          .from('account')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      Account account;
      if (existing != null) {
        account = Account.fromJson(existing);
      } else {
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

  /// Step 1 of "forgot password": Supabase emails a 6-digit code (email
  /// template must use `{{ .Token }}`, not the confirmation link). Whole
  /// flow stays in-app — no browser hand-off, no deep link.
  Future<Map<String, dynamic>> sendPasswordResetCode(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
      return {
        'status': 'success',
        'message': 'If an account exists for that email, a verification code has been sent.',
      };
    } catch (e) {
      debugPrint('AuthService.sendPasswordResetCode error: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Step 2: verifies the emailed code (exchanges it for a temporary
  /// recovery session) and sets the new password in the same call.
  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      await supabase.auth.signOut();
      return {'status': 'success', 'message': 'Password updated successfully.'};
    } catch (e) {
      debugPrint('AuthService.verifyResetCode error: $e');
      return {'status': 'error', 'message': 'Invalid or expired code. Please try again.'};
    }
  }

  /// Verifies the signup confirmation code (the "Confirm signup" email
  /// template must use `{{ .Token }}`, not the confirmation link). On
  /// success, creates the `account` row now — signUp() couldn't create it
  /// earlier because no session existed yet before the email was confirmed.
  Future<Map<String, dynamic>> verifySignupCode({
    required String email,
    required String token,
    required String name,
  }) async {
    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      final user = response.user;
      if (user == null) {
        return {'status': 'error', 'message': 'Invalid or expired code. Please try again.'};
      }

      final existing = await supabase
          .from('account')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      Account account;
      if (existing != null) {
        account = Account.fromJson(existing);
      } else {
        final inserted = await supabase
            .from('account')
            .insert({
          'id': user.id,
          'name': name,
          'email': email,
          'role': 'user',
        })
            .select()
            .single();
        account = Account.fromJson(inserted);
      }

      return {'status': 'success', 'account': account};
    } catch (e) {
      debugPrint('AuthService.verifySignupCode error: $e');
      return {'status': 'error', 'message': 'Invalid or expired code. Please try again.'};
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

  /// Uploads [bytes] as the user's avatar (fixed path per user, so a
  /// re-upload overwrites the old one instead of accumulating files),
  /// saves the resulting public URL on the account row, and returns it.
  /// A timestamp query param is appended so cached copies of the old
  /// image at the same URL don't get shown after an update.
  Future<String?> uploadAvatar({
    required String id,
    required Uint8List bytes,
  }) async {
    try {
      final path = '$id/avatar.jpg';
      await supabase.storage
          .from(_avatarBucket)
          .uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final publicUrl = supabase.storage.from(_avatarBucket).getPublicUrl(path);
      final avatarUrl = '$publicUrl?updated=${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('account').update({'avatar_url': avatarUrl}).eq('id', id);
      return avatarUrl;
    } catch (e) {
      debugPrint('AuthService.uploadAvatar error: $e');
      return null;
    }
  }
}