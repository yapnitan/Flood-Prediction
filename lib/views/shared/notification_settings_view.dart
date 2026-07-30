import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';

class NotificationSettingsView extends StatefulWidget {
  final Account account;

  const NotificationSettingsView({super.key, required this.account});

  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  final _authController = AuthController(AuthService());

  late bool _notifyEmail;
  late bool _notifyPush;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notifyEmail = widget.account.notifyEmail;
    _notifyPush = widget.account.notifyPush;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final ok = await _authController.updateNotificationPrefs(
      id: widget.account.id,
      notifyEmail: _notifyEmail,
      notifyPush: _notifyPush,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(
        context,
        widget.account.copyWith(notifyEmail: _notifyEmail, notifyPush: _notifyPush),
      );
    } else {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save notification settings')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            context.responsive(mobile: 20, tablet: 32, desktop: 40),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(mobile: 520, tablet: 560),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Email notifications'),
                          subtitle: const Text('Flood alerts and assessment updates by email'),
                          value: _notifyEmail,
                          onChanged: (value) => setState(() => _notifyEmail = value),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Push notifications'),
                          subtitle: const Text('Real-time alerts on this device'),
                          value: _notifyPush,
                          onChanged: (value) => setState(() => _notifyPush = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
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
