import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _authController = AuthController(AuthService());

  bool _isSubmitting = false;
  String _errorMessage = '';
  bool _emailSent = false;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final result = await _authController.sendPasswordReset(email);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (result['status'] == 'success') {
        _emailSent = true;
      } else {
        _errorMessage = result['message'] ?? 'Something went wrong';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsive(mobile: 20, tablet: 32, desktop: 40),
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(mobile: 480, tablet: 520),
              ),
              child: _emailSent ? _buildSentState() : _buildFormState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_reset, size: 56, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Reset your password',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter the email associated with your account and we'll send you a link to reset your password.",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        if (_errorMessage.isNotEmpty) ...[
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
        ],

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'example@gmail.com',
            prefixIcon: const Icon(Icons.email, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Send Reset Link',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Login'),
          ),
        ),
      ],
    );
  }

  Widget _buildSentState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.mark_email_read, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Check your inbox',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a password reset link to ${_emailController.text.trim()}. "
          "Open it on this device to set a new password.",
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Login'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
