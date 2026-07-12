import '../models/account.dart';

class UserModel extends Account{
  UserModel({required super.id, required super.name, required super.email, required super.password, super.role = "user"});

}