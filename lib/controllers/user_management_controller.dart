import '../models/account.dart';
import '../services/user_management_service.dart';

class UserManagementController {
  final UserManagementService userManagementService;

  UserManagementController(this.userManagementService);

  Future<List<Account>> listUsers() {
    return userManagementService.getAllAccounts();
  }

  Future<bool> changeRole(String id, String role) {
    return userManagementService.updateRole(id, role);
  }

  Future<bool> setActive(String id, bool isActive) {
    return userManagementService.setActive(id, isActive);
  }

  /// Approve ('active') or reject ('rejected') a pending sign-up.
  Future<bool> changeStatus(String id, String status) {
    return userManagementService.updateStatus(id, status);
  }

  Future<bool> removeUser(String id) {
    return userManagementService.deleteAccount(id);
  }
}
