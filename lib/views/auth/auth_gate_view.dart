import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';

/// App's actual starting screen: if there's already a valid Supabase
/// session (app was reopened without logging out), skip straight to the
/// right home screen instead of always forcing the user back through
/// Login. Falls back to Login if there's no session, the account row is
/// missing, or the account is disabled/pending/rejected — mirroring the
/// same gates [AuthService.loginValidate] applies on a fresh login.
class AuthGateView extends StatefulWidget {
  const AuthGateView({super.key});

  @override
  State<AuthGateView> createState() => _AuthGateViewState();
}

class _AuthGateViewState extends State<AuthGateView> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final user = Supabase.instance.client.auth.currentSession?.user;
    if (user == null) {
      _goTo(AppRoutes.login);
      return;
    }

    final account = await AuthController(AuthService()).getAccount(user.id);
    if (!mounted) return;

    if (account == null || !account.isActive || account.status != 'active') {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      _goTo(AppRoutes.login);
      return;
    }

    final destination = switch (account.role) {
      'admin' => AppRoutes.adminHome,
      'helper' => AppRoutes.helperHome,
      _ => AppRoutes.userHome,
    };
    _goTo(destination);
  }

  void _goTo(String route) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
