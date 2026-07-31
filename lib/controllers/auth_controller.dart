import 'dart:typed_data';

import '../models/account.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService authService;

  AuthController(this.authService);

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    return await authService.register(name, email, password);
  }

  Future<LoginResult> login(String email, String password) {
    return authService.loginValidate(email, password);
  }

  Future<void> logout() {
    return authService.logout();
  }

  Future<Account?> getAccount(String id) {
    return authService.getAccountById(id);
  }

  Future<Map<String, dynamic>> sendPasswordReset(String email) {
    return authService.sendPasswordResetEmail(email);
  }

  Future<Map<String, dynamic>> updatePassword(String newPassword) {
    return authService.updatePassword(newPassword);
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
