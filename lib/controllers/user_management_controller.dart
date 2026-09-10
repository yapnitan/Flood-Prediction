import '../models/account.dart';
import '../services/user_management_service.dart';

class UserManagementController {
  final UserManagementService userManagementService;

  UserManagementController(this.userManagementService);

  Future<List<Account>> listUsers() {
    return userManagementService.getAllAccounts();
  }

  Future<bool> changeRole(String id, String role, {bool activate = false}) {
    return userManagementService.updateRole(id, role, activate: activate);
  }

  Future<bool> setActive(String id, bool isActive) {
    return userManagementService.setActive(id, isActive);
  }

  Future<bool> changeStatus(String id, String status) {
    return userManagementService.updateStatus(id, status);
  }
}
