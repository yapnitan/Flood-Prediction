import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';


class AuthService {

  final supabase = Supabase.instance.client;


  Future<Account?> loginValidate(
      String email,
      String password
      ) async {

    try {

      // Login using Supabase Auth
      final response =
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );


      final user = response.user;


      if(user == null){
        return null;
      }


      // Get user profile
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();


      return Account.fromJson(profile);


    } catch(e){

      print(e);
      return null;

    }
  }
}