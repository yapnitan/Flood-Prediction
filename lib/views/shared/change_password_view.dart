import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/password_field.dart';

/// Lets an already-logged-in user change their password from Profile,
/// without going through the email-code "forgot password" flow.
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authController = AuthController(AuthService());

  bool _isSubmitting = false;
  String? _currentError;
  String? _newError;
  String? _confirmError;

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final current = _currentController.text.trim();
    final newPassword = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    setState(() {
      _currentError = current.isEmpty ? 'Enter your current password' : null;
      _newError = (newPassword.isEmpty || newPassword.length < 8)
          ? 'New password must be at least 8 characters'
          : null;
      _confirmError = newPassword != confirm
          ? 'New passwords do not match'
          : null;
    });
    if (_currentError != null || _newError != null || _confirmError != null) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSubmitting = true;
    });

    final result = await _authController.changePassword(
      currentPassword: current,
      newPassword: newPassword,
    );

    if (!mounted) return;

    if (result['status'] == 'success') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated.')));
      Navigator.pop(context);
    } else {
      final message =
          result['message'] as String? ?? 'Failed to update password';
      setState(() {
        _isSubmitting = false;
        // changePassword only fails by rejecting the current password or a
        // generic update error — the former belongs on that field, the
        // latter is shown on the new-password field next to it.
        if (message.toLowerCase().contains('current password')) {
          _currentError = message;
        } else {
          _newError = message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Change Password'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              context.responsive(mobile: 20, tablet: 32, desktop: 40),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.responsive(mobile: 480, tablet: 520),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PasswordField(
                      controller: _currentController,
                      labelText: 'Current password',
                      prefixIcon: Icons.lock_outline,
                      errorText: _currentError,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _newController,
                      labelText: 'New password',
                      errorText: _newError,
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
                        onPressed: _isSubmitting ? null : _submit,
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
                                'Update Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
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

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
