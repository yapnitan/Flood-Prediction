import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../routes/app_routes.dart';

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
    String email = emailController.text.trim();
    String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = "Please enter both email and password");
      return;
    }

    final result = await authController.login(email, password);
    if (!mounted) return;

    if (result.account == null) {
      setState(() {
        errorMessage = result.error ?? "Invalid email or password";
      });
      return;
    }

    setState(() {
      errorMessage = "";
    });

    final account = result.account!;
    if (account.role == "admin") {
      Navigator.pushNamed(context, AppRoutes.adminHome);
    } else if (account.role == "helper") {
      Navigator.pushNamed(context, AppRoutes.helperHome);
    } else {
      Navigator.pushNamed(context, AppRoutes.userHome);
    }
  }

  void forgotPassword() {
    Navigator.pushNamed(context, AppRoutes.forgotPassword);
  }

  void register() {
    Navigator.pushNamed(context, AppRoutes.register);
  }

  void verifyEmail() {
    Navigator.pushNamed(context, AppRoutes.verifyEmail);
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
          padding: EdgeInsets.symmetric(
            horizontal: context.responsive(mobile: 20, tablet: 32, desktop: 40),
            vertical: 20,
          ),

          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(
                  mobile: 480,
                  tablet: 520,
                  desktop: 480,
                ),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,

                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    "assets/images/logo.png",
                    width: context.responsive(mobile: 120.0, tablet: 150.0),
                    height: context.responsive(mobile: 120.0, tablet: 150.0),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (errorMessage.isNotEmpty)
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: verifyEmail,
                        child: const Text("Confirm email"),
                      ),
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
