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

  /// [role] is 'user' or 'helper' (never 'admin' — admins are promoted by an
  /// existing admin in User Management, not self-registered). Helper
  /// sign-ups start with [Account.status] 'pending' and need admin approval
  /// before [loginValidate] will let them in.
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
        // role is stashed in user metadata (not just passed around in
        // widget state) so it survives even if the user abandons the app
        // before entering the code and comes back later via the
        // "resend confirmation code" flow on the login page.
        data: {'name': name, 'role': role},
      );

      final user = response.user;

      if (user == null) {
        return {'status': 'error', 'message': 'Registration failed'};
      }

      // Supabase doesn't error on signUp() for an email that's already
      // registered and confirmed — to avoid leaking which emails exist, it
      // returns a look-alike successful response (a user object, but with
      // an empty identities list) and sends nothing. Without this check the
      // app would tell the user to "check their email" for a code that was
      // never sent.
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

  /// Maps Supabase's raw signUp() error text/codes to messages a user can
  /// actually act on, instead of showing them `AuthApiException(...)`
  /// verbatim.
  String _friendlySignUpError(AuthApiException e) {
    final message = e.message.toLowerCase();
    if (e.code == 'user_already_exists' || message.contains('already registered')) {
      return 'This email is already registered. Please log in instead.';
    }
    if (message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (message.contains('password')) {
      // Already a specific, actionable message (e.g. "Password should be
      // at least 6 characters") — worth showing as-is.
      return e.message;
    }
    if (message.contains('email') && (message.contains('invalid') || message.contains('valid'))) {
      return 'Please enter a valid email address.';
    }
    return e.message;
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
    } on AuthApiException catch (e) {
      debugPrint("Login error: $e");
      // Supabase rejects signInWithPassword outright for an unconfirmed
      // email — there's no account row to check yet at that point, so this
      // has to be caught here rather than as an Account.status check above.
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

  /// Changes the password for the currently signed-in user. Re-verifies
  /// [currentPassword] with a fresh sign-in first — Supabase's updateUser()
  /// would happily change the password on an already-valid session without
  /// asking for it, but requiring it here stops an unlocked/unattended
  /// device from having its password silently changed.
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
    } on AuthApiException catch (e) {
      debugPrint('AuthService.sendPasswordResetCode error: $e');
      // e.message (not e.toString()) is kept as-is here rather than mapped
      // to a generic string — for a rate-limit error it's the only place
      // the "after N seconds" text lives, which the UI parses to show a
      // countdown (see ForgotPasswordPage._extractRateLimitSeconds).
      return {'status': 'error', 'message': e.message};
    } catch (e) {
      debugPrint('AuthService.sendPasswordResetCode error: $e');
      return {'status': 'error', 'message': 'Something went wrong. Please try again.'};
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
  ///
  /// [name]/[role] are only needed when called right after [register] (which
  /// already has them in memory). When this is called later from the
  /// "resend confirmation code" flow on the login page — where the app has
  /// no memory of the original registration form — they're omitted and
  /// recovered from the signup's user metadata instead (see [register]).
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

  /// Re-sends the signup confirmation code for an account that was created
  /// but never confirmed (the user closed the app before entering the
  /// code). Reached from the login page, not the registration form.
  Future<Map<String, dynamic>> resendSignupCode(String email) async {
    try {
      await supabase.auth.resend(type: OtpType.signup, email: email);
      return {
        'status': 'success',
        'message': 'If that account is awaiting confirmation, a new code has been sent.',
      };
    } on AuthApiException catch (e) {
      debugPrint('AuthService.resendSignupCode error: $e');
      // Supabase rejects resend() outright (rather than silently no-op'ing,
      // like signUp() does) when the account is already confirmed — surface
      // that distinctly instead of a generic failure message.
      if (e.message.toLowerCase().contains('already confirmed')) {
        return {
          'status': 'error',
          'message': 'This email is already confirmed. Please log in instead.',
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