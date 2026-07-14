import '../models/account.dart';
import '../models/admin_model.dart';
import '../models/helper_model.dart';
import '../models/user_model.dart';

class AuthService {
  List<Account> accounts = [];
  AuthService() {
    accounts.add(
      UserModel(
        id: "U001",
        name: "Ahmad",
        email: "user@gmail.com",
        password: "123456",
      ),
    );

    accounts.add(
      HelperModel(
        id: "H001",
        name: "Ali",
        email: "helper@gmail.com",
        password: "123456",
      ),
    );

    accounts.add(
      AdminModel(
        id: "A001",
        name: "Admin",
        email: "admin@gmail.com",
        password: "123456",
      ),
    );
  }

  Account? loginValidate(String email, String password) {
    for (var account in accounts) {
      if (account.email == email && account.password == password) {
        return account;
      }
    }
    return null;
  }
}
