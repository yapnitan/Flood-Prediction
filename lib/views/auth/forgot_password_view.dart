import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/password_field.dart';
import 'dart:async';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authController = AuthController(AuthService());

  bool _isSendingCode = false;
  bool _isSubmitting = false;
  String? _emailError;
  String? _codeError;
  String? _passwordError;
  String? _confirmError;
  bool _codeSent = false;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isSendingCode = true;
      _emailError = null;
    });

    final result = await _authController.sendPasswordResetCode(email);

    if (!mounted) return;

    if (result['status'] == 'success') {
      setState(() {
        _isSendingCode = false;
        _codeSent = true;
      });
    } else {
      final message = result['message'] as String? ?? '';
      final waitSeconds = _extractRateLimitSeconds(message);

      setState(() {
        _isSendingCode = false;
        if (waitSeconds != null) {
          _emailError = null;
          _startCooldown(waitSeconds);
        } else {
          _emailError = 'Something went wrong. Please try again.';
        }
      });
    }
  }

  int? _extractRateLimitSeconds(String message) {
    final match = RegExp(r'after (\d+) seconds').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _submitNewPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    setState(() {
      _codeError = code.isEmpty ? 'Enter the code from your email' : null;
      _passwordError = (password.isEmpty || password.length < 8)
          ? 'Password must be at least 8 characters'
          : null;
      _confirmError = password != confirm ? 'Passwords do not match' : null;
    });
    if (_codeError != null || _passwordError != null || _confirmError != null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await _authController.verifyResetCode(
      email: _emailController.text.trim(),
      token: code,
      newPassword: password,
    );

    if (!mounted) return;

    if (result['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Please log in again.')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _isSubmitting = false;
        _codeError = result['message'] ?? 'Failed to update password';
      });
    }
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
              child: _codeSent ? _buildCodeStep() : _buildEmailStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
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
          "Enter the email associated with your account and we'll send you a "
              "6-digit verification code.",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'example@gmail.com',
            errorText: _emailError,
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
            onPressed: (_isSendingCode || _cooldownSeconds > 0) ? null : _sendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSendingCode
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            )
                : Text(
              _cooldownSeconds > 0
                  ? 'Resend in ${_cooldownSeconds}s'
                  : 'Send Verification Code',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.mark_email_read, size: 56, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Check your inbox',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a verification code to ${_emailController.text.trim()}. "
              "Enter it below along with your new password.",
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Verification code',
            hintText: '6-digit code',
            errorText: _codeError,
            prefixIcon: const Icon(Icons.pin, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _passwordController,
          labelText: 'New password',
          errorText: _passwordError,
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _confirmController,
          labelText: 'Confirm new password',
          prefixIcon: Icons.lock_outline,
          errorText: _confirmError,
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitNewPassword,
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
              'Update Password',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _isSendingCode ? null : _sendCode,
            child: const Text("Didn't get a code? Resend"),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}