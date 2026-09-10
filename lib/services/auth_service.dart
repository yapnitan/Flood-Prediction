import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';

const String _avatarBucket = 'avatars';

class LoginResult {
  final Account? account;
  final String? error;

  LoginResult.success(this.account) : error = null;
  LoginResult.failure(this.error) : account = null;
}

class AuthService {

  SupabaseClient get supabase => Supabase.instance.client;

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,

        data: {'name': name, 'role': role},
      );

      final user = response.user;

      if (user == null) {
        return {'status': 'error', 'message': 'Registration failed'};
      }

      if (user.identities != null && user.identities!.isEmpty) {
        return {
          'status': 'error',
          'message': 'This email is already registered. Please log in instead.',
        };
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
          .insert({
        'id': user.id,
        'name': name,
        'email': email,
        'role': role,
        'status': role == 'helper' ? 'pending' : 'active',
      })
          .select()
          .single();

      return {'status': 'success', 'account': Account.fromJson(account)};
    } on AuthApiException catch (e) {
      debugPrint("Register error: $e");
      return {'status': 'error', 'message': _friendlySignUpError(e)};
    } catch (e) {
      debugPrint("Register error: $e");
      return {'status': 'error', 'message': 'Something went wrong. Please try again.'};
    }
  }

  String _friendlySignUpError(AuthApiException e) {
    final message = e.message.toLowerCase();
    if (e.code == 'user_already_exists' || message.contains('already registered')) {
      return 'This email is already registered. Please log in instead.';
    }
    if (message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (message.contains('password')) {

      return e.message;
    }
    if (message.contains('email') && (message.contains('invalid') || message.contains('valid'))) {
      return 'Please enter a valid email address.';
    }
    return e.message;
  }

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
    } on AuthApiException catch (e) {
      debugPrint("Login error: $e");

      if (e.code == 'email_not_confirmed') {
        return LoginResult.failure(
          "Please confirm your email first — use \"Confirm email\" below to get a new code.",
        );
      }
      return LoginResult.failure('Invalid email or password');
    } catch (e) {
      debugPrint("Login error: $e");
      return LoginResult.failure('Invalid email or password');
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) {
      return {'status': 'error', 'message': 'Not signed in'};
    }

    try {
      await supabase.auth.signInWithPassword(email: email, password: currentPassword);
    } catch (e) {
      return {'status': 'error', 'message': 'Current password is incorrect'};
    }

    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      return {'status': 'success', 'message': 'Password updated successfully.'};
    } catch (e) {
      debugPrint('AuthService.changePassword error: $e');
      return {'status': 'error', 'message': 'Failed to update password'};
    }
  }

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

  Future<Account?> getAccountByEmail(String email) async {
    try {
      final row = await supabase
          .from('account')
          .select()
          .eq('email', email)
          .maybeSingle();
      return row != null ? Account.fromJson(row) : null;
    } catch (e) {
      debugPrint('AuthService.getAccountByEmail error: $e');
      return null;
    }
  }


  Future<Map<String, dynamic>> sendPasswordResetCode(String email) async {

    final account = await getAccountByEmail(email);
    if (account != null) {
      if (account.status == 'pending') {
        return {
          'status': 'error',
          'message': 'Your account is still pending admin approval. You can reset your password once it\'s approved.',
        };
      }
      if (account.status == 'rejected') {
        return {
          'status': 'error',
          'message': 'Your account application was rejected. Please contact an administrator.',
        };
      }
      if (!account.isActive) {
        return {
          'status': 'error',
          'message': 'Your account has been disabled. Please contact an administrator.',
        };
      }
    }

    try {
      await supabase.auth.resetPasswordForEmail(email);
      return {
        'status': 'success',
        'message': 'If an account exists for that email, a verification code has been sent.',
      };
    } on AuthApiException catch (e) {
      debugPrint('AuthService.sendPasswordResetCode error: $e');

      return {'status': 'error', 'message': e.message};
    } catch (e) {
      debugPrint('AuthService.sendPasswordResetCode error: $e');
      return {'status': 'error', 'message': 'Something went wrong. Please try again.'};
    }
  }


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

  Future<Map<String, dynamic>> verifySignupCode({
    required String email,
    required String token,
    String? name,
    String? role,
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
        final resolvedName = name ?? user.userMetadata?['name'] as String? ?? '';
        final resolvedRole = role ?? user.userMetadata?['role'] as String? ?? 'user';
        final inserted = await supabase
            .from('account')
            .insert({
          'id': user.id,
          'name': resolvedName,
          'email': email,
          'role': resolvedRole,
          'status': resolvedRole == 'helper' ? 'pending' : 'active',
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

  Future<String> emailAccountStatus(String email) async {
    try {
      final result = await supabase.rpc(
        'auth_email_status',
        params: {'p_email': email},
      );
      return result as String? ?? 'unknown';
    } catch (e) {
      debugPrint('AuthService.emailAccountStatus error: $e');
      return 'unknown';
    }
  }

  Future<Map<String, dynamic>> resendSignupCode(String email) async {
    try {
      switch (await emailAccountStatus(email)) {
        case 'not_registered':
          return {
            'status': 'not_registered',
            'message':
                "You haven't signed up with this email yet. Create an account first.",
          };
        case 'confirmed':
          return {
            'status': 'error',
            'message': 'This email is already confirmed. Please log in instead.',
          };
      }

      await supabase.auth.resend(type: OtpType.signup, email: email);
      return {
        'status': 'success',
        'message': 'A new confirmation code has been sent to your email.',
      };
    } on AuthApiException catch (e) {
      debugPrint('AuthService.resendSignupCode error: $e');
      final message = e.message.toLowerCase();
      if (message.contains('already confirmed')) {
        return {
          'status': 'error',
          'message': 'This email is already confirmed. Please log in instead.',
        };
      }
      if (e.code == 'user_not_found' || message.contains('user not found')) {
        return {
          'status': 'not_registered',
          'message':
              "You haven't signed up with this email yet. Create an account first.",
        };
      }
      return {'status': 'error', 'message': e.message};
    } catch (e) {
      debugPrint('AuthService.resendSignupCode error: $e');
      return {'status': 'error', 'message': 'Something went wrong. Please try again.'};
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