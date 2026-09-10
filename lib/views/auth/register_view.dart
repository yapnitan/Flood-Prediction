import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../widgets/password_field.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegistrationPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final codeController = TextEditingController();

  final AuthController authController = AuthController(AuthService());

  String? nameError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;
  String? codeError;
  bool isSubmitting = false;
  bool codeSent = false;

  String selectedRole = "user";

  void _clearFormErrors() {
    nameError = null;
    emailError = null;
    passwordError = null;
    confirmPasswordError = null;
  }

  Future<void> register() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    setState(() {
      _clearFormErrors();
      if (name.isEmpty) nameError = "Please enter your name";
      if (email.isEmpty) emailError = "Please enter your email";
      if (password.isEmpty) {
        passwordError = "Please enter a password";
      } else if (password.length < 8) {
        passwordError = "Password must be at least 8 characters";
      }
      if (confirmPassword.isEmpty) {
        confirmPasswordError = "Please confirm your password";
      } else if (password != confirmPassword) {
        confirmPasswordError = "Passwords do not match";
      }
    });
    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    final result = await authController.register(name, email, password, selectedRole);

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (result['status'] == 'confirm_email') {
      setState(() => codeSent = true);
    } else if (result['status'] == 'success') {

      _handleRegistrationSuccess();
    } else {
      final message = result['message'] as String? ?? "Registration failed";

      setState(() {
        if (message.toLowerCase().contains('password')) {
          passwordError = message;
        } else {
          emailError = message;
        }
      });
    }
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() => codeError = 'Enter the code from your email');
      return;
    }

    setState(() {
      isSubmitting = true;
      codeError = null;
    });

    final result = await authController.verifySignupCode(
      email: emailController.text.trim(),
      token: code,
      name: nameController.text.trim(),
      role: selectedRole,
    );

    if (!mounted) return;

    if (result['status'] == 'success') {
      _handleRegistrationSuccess();
    } else {
      setState(() {
        isSubmitting = false;
        codeError = result['message'] ?? 'Invalid or expired code. Please try again.';
      });
    }
  }

  void _handleRegistrationSuccess() {
    if (selectedRole == 'helper') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your helper application was submitted and is awaiting admin approval. '
            "You'll be able to log in once it's approved.",
          ),
          duration: Duration(seconds: 5),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
            (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account verified! Welcome to FloodWatch.')),
    );
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.userHome,
          (route) => false,
    );
  }

  void backToLogin() {
    Navigator.pop(context);
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 16,
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      errorText: errorText,
      prefixIcon: Icon(icon, color: Colors.blue),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          codeSent ? "Verify Your Email" : "Register Account",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 5,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsive(mobile: 20, tablet: 32, desktop: 40),
          vertical: 20,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(mobile: 480, tablet: 520, desktop: 480),
              ),
              child: codeSent ? _buildCodeStep() : _buildFormStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return Column(
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
          controller: nameController,
          maxLength: 20,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          decoration: _decoration(
            label: "Enter your name",
            hint: "John Doe",
            icon: Icons.person,
            errorText: nameError,
          ),
        ),
        const SizedBox(height: 20),

        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Register as",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text("Resident"),
                selected: selectedRole == "user",
                onSelected: (_) => setState(() => selectedRole = "user"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text("Helper"),
                selected: selectedRole == "helper",
                onSelected: (_) => setState(() => selectedRole = "helper"),
              ),
            ),
          ],
        ),
        if (selectedRole == "helper") ...[
          const SizedBox(height: 8),
          Text(
            "Helper accounts need admin approval before you can log in.",
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
        const SizedBox(height: 20),

        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          decoration: _decoration(
            label: "Enter your email",
            hint: "example@gmail.com",
            icon: Icons.email,
            errorText: emailError,
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
        const SizedBox(height: 20),

        PasswordField(
          controller: confirmPasswordController,
          labelText: "Confirm your password",
          hintText: "********",
          prefixIcon: Icons.lock_outline,
          bold: true,
          errorText: confirmPasswordError,
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : register,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isSubmitting
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
                : const Text(
              "Register",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text("Already have an account?"),
            TextButton(onPressed: backToLogin, child: const Text("Login")),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.mark_email_read, size: 56, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Check your inbox',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a verification code to ${emailController.text.trim()}. "
              "Enter it below to activate your account.",
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          decoration: _decoration(
            label: "Verification code",
            hint: "Enter the code from your email",
            icon: Icons.pin,
            errorText: codeError,
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isSubmitting
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
                : const Text(
              'Verify & Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: isSubmitting ? null : register,
            child: const Text("Didn't get a code? Resend"),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    codeController.dispose();
    super.dispose();
  }
}