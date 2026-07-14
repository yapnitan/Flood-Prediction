import 'account.dart';

class AdminModel extends Account{
  AdminModel({required super.id, required super.name, required super.email, required super.password, super.role = "admin"});

}