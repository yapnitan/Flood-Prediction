import 'dart:typed_data';

import '../models/account.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService authService;

  AuthController(this.authService);

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    return await authService.register(name, email, password, role);
  }

  Future<LoginResult> login(String email, String password) {
    return authService.loginValidate(email, password);
  }

  Future<void> logout() {
    return authService.logout();
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<Account?> getAccount(String id) {
    return authService.getAccountById(id);
  }

  Future<Map<String, dynamic>> sendPasswordResetCode(String email) {
    return authService.sendPasswordResetCode(email);
  }

  Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String token,
    required String newPassword,
  }) {
    return authService.verifyResetCode(email: email, token: token, newPassword: newPassword);
  }

  Future<Map<String, dynamic>> verifySignupCode({
    required String email,
    required String token,
    String? name,
    String? role,
  }) {
    return authService.verifySignupCode(email: email, token: token, name: name, role: role);
  }

  Future<Map<String, dynamic>> resendSignupCode(String email) {
    return authService.resendSignupCode(email);
  }

  Future<bool> updateProfile({required String id, required String name}) {
    return authService.updateProfile(id: id, name: name);
  }

  Future<bool> updateNotificationPrefs({
    required String id,
    required bool notifyEmail,
    required bool notifyPush,
  }) {
    return authService.updateNotificationPrefs(
      id: id,
      notifyEmail: notifyEmail,
      notifyPush: notifyPush,
    );
  }

  Future<String?> uploadAvatar({required String id, required Uint8List bytes}) {
    return authService.uploadAvatar(id: id, bytes: bytes);
  }
}