import 'dart:async';

import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../models/account.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../routes/app_routes.dart';

/// Reached from the login page by a user who registered but closed the app
/// before entering the confirmation code — resends the code, then verifies
/// it. Unlike [RegistrationPage]'s inline code step, this doesn't have the
/// original name/role in memory, so [AuthService.verifySignupCode] recovers
/// them from the signup's stored user metadata instead.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _authController = AuthController(AuthService());

  bool _isSendingCode = false;
  bool _isSubmitting = false;
  String _errorMessage = '';
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
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorMessage = '';
    });

    final result = await _authController.resendSignupCode(email);

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
          _errorMessage = '';
          _startCooldown(waitSeconds);
        } else {
          _errorMessage = 'Something went wrong. Please try again.';
        }
      });
    }
  }

  /// Parses Supabase's rate-limit message (e.g. "...after 47 seconds...")
  /// to show a friendly countdown instead of the raw exception text. Keyed
  /// off the "after N seconds" phrasing itself rather than the exception's
  /// `over_email_send_rate_limit` code, since AuthService now passes through
  /// the clean `e.message` (no code embedded) for this case.
  int? _extractRateLimitSeconds(String message) {
    final match = RegExp(r'after (\d+) seconds').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Enter the code from your email');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final result = await _authController.verifySignupCode(
      email: _emailController.text.trim(),
      token: code,
    );

    if (!mounted) return;

    if (result['status'] == 'success') {
      _handleVerified(result['account'] as Account);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = result['message'] ?? 'Invalid or expired code. Please try again.';
      });
    }
  }

  /// A helper account still pending admin approval can't log in yet — send
  /// them back to Login with an explanation instead of into the app.
  void _handleVerified(Account account) {
    if (account.status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email confirmed. Your helper application is still awaiting admin approval.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email confirmed! Welcome to FloodWatch.')),
    );

    final destination = switch (account.role) {
      'admin' => AppRoutes.adminHome,
      'helper' => AppRoutes.helperHome,
      _ => AppRoutes.userHome,
    };
    Navigator.pushNamedAndRemoveUntil(context, destination, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Email'),
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
        const Icon(Icons.mark_email_unread, size: 56, color: Colors.blue),
        const SizedBox(height: 16),
        const Text(
          'Confirm your email',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "If you signed up but never entered the code, enter your email and "
          "we'll send a new one.",
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
                        : 'Send Confirmation Code',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
          "We've sent a confirmation code to ${_emailController.text.trim()}. "
          "Enter it below.",
          style: const TextStyle(color: Colors.grey),
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
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Confirmation code',
            hintText: '6-digit code',
            prefixIcon: const Icon(Icons.pin, color: Colors.blue),
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
            onPressed: _isSubmitting ? null : _verifyCode,
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
                    'Verify & Continue',
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
    super.dispose();
  }
}
