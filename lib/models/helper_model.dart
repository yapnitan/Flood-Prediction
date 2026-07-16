import 'account.dart';

class HelperModel extends Account{
  HelperModel({required super.id, required super.name, required super.email, super.role = "helper"});

}