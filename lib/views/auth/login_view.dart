import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../widgets/password_field.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final AuthController authController = AuthController(AuthService());

  String? emailError;
  String? passwordError;
  bool _isSubmitting = false;

  Future<void> login() async {
    if (_isSubmitting) return;

    String email = emailController.text.trim();
    String password = passwordController.text;

    setState(() {
      emailError = email.isEmpty ? "Please enter your email" : null;
      passwordError = password.isEmpty ? "Please enter your password" : null;
    });
    if (emailError != null || passwordError != null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);

    late final LoginResult result;
    try {
      result = await authController.login(email, password);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        passwordError = 'Unable to sign in. Please try again.';
      });
      return;
    }
    if (!mounted) return;

    if (result.account == null) {
      // Not attributable to one field (wrong password vs. disabled/pending
      // account are all auth-level failures) — shown under password since
      // it's the field closest to the submit action.
      setState(() {
        _isSubmitting = false;
        passwordError = result.error ?? "Invalid email or password";
      });
      return;
    }

    setState(() {
      passwordError = null;
    });

    final account = result.account!;
    // Clears Login (and anything else) out of the nav stack — a plain
    // pushNamed would leave Login sitting underneath Home, so the device
    // back button from Home would pop back to Login instead of exiting/
    // switching tabs.
    final destination = switch (account.role) {
      "admin" => AppRoutes.adminHome,
      "helper" => AppRoutes.helperHome,
      _ => AppRoutes.userHome,
    };
    Navigator.pushNamedAndRemoveUntil(context, destination, (route) => false);
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
    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: Scaffold(
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
              horizontal: context.responsive(
                mobile: 20,
                tablet: 32,
                desktop: 40,
              ),
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

                        errorText: emailError,

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

                    PasswordField(
                      controller: passwordController,
                      labelText: "Enter your password",
                      hintText: "********",
                      bold: true,
                      errorText: passwordError,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 4,
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
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
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
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
      ),
    );
  }
}
