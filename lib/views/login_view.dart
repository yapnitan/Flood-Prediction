import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import 'user_view.dart';
import 'admin_view.dart';
import 'helper_view.dart';
import 'register_view.dart';
import 'forgot_password_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final AuthController authController = AuthController(AuthService());

  String errorMessage = "";

  Future<void> login() async {
    String email = emailController.text;
    String password = passwordController.text;

    // TEMPORARY: hardcoded test accounts, bypasses Supabase
    if (email == "admin" && password == "123") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdminHome()),
      );
      return;
    }
    if (email == "user" && password == "123") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => UserHome()),
      );
      return;
    }

    var account = await authController.login(email, password);
    if (!mounted) return;
    if (account == null) {
      setState(() {
        errorMessage = "Invalid email or password";
      });
    } else {
      setState(() {
        errorMessage = "";
      });

      if (account.role == "admin") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminHome()),
        );
      } else if (account.role == "helper") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HelperHome()),
        );
      } else if (account.role == "user") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => UserHome()),
        );
      }
    }
  }

  void forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
    );
  }

  void register() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegistrationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        title: const Text(
          "Login Page",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        centerTitle: true,

        backgroundColor: Colors.white,

        elevation: 5,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,

                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    "assets/images/logo.png",
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (errorMessage.isNotEmpty)
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),

                  TextField(
                    controller: emailController,

                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),

                    decoration: InputDecoration(
                      labelText: "Enter your email",

                      labelStyle: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),

                      hintText: "example@gmail.com",

                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),

                      prefixIcon: const Icon(Icons.email, color: Colors.blue),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),

                        borderSide: const BorderSide(
                          color: Colors.grey,
                          width: 1,
                        ),
                      ),

                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),

                        borderSide: const BorderSide(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),

                      filled: true,

                      fillColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: "Enter your password",
                      labelStyle: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),

                      hintText: "********",

                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),

                      prefixIcon: const Icon(Icons.lock, color: Colors.blue),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),

                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),

                        borderSide: const BorderSide(
                          color: Colors.grey,
                          width: 1,
                        ),
                      ),

                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),

                        borderSide: const BorderSide(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: forgotPassword,
                        child: const Text("Forgot Password?"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,

                    height: 50,

                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: register,
                        child: const Text("Sign Up"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
