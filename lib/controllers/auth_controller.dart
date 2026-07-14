import '../models/account.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService authService;

  AuthController(this.authService);

  Account? login(String email, String password) {
    Account? account = authService.loginValidate(email, password);

    return account;
  }
}
