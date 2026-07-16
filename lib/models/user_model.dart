import 'account.dart';

class UserModel extends Account{
  UserModel({required super.id, required super.name, required super.email, super.role = "user"});

}