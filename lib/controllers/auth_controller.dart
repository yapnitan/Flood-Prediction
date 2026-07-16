import '../models/account.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService authService;

  AuthController(this.authService);

  Future<Account?> register(String name, String email, String password) async {
    Account? account = await authService.register(name, email, password);

    return account;
  }

  Future<Account?> login(String email, String password) async {
    Account? account = await authService.loginValidate(email, password);

    return account;
  }
}
