import '../models/account.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService authService;

  AuthController(this.authService);

  Future<Account?> login(String email, String password) async {
    Account? account = await authService.loginValidate(email, password);

    return account;
  }
}
