import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';
import 'package:app_links/app_links.dart';

import 'views/login_view.dart';
import 'views/reset_password_view.dart';

/// Lets the passwordRecovery listener below push a new screen without a
/// BuildContext of its own (it fires from a top-level stream listener).
final navigatorKey = GlobalKey<NavigatorState>();
final _appLinks = AppLinks();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  // App was cold-started BY tapping the reset link — grab it directly.
  final initialUri = await _appLinks.getInitialLink();
  if (initialUri != null) {
    await _handleIncomingLink(initialUri);
  }

  // App was already running when the link was tapped.
  _appLinks.uriLinkStream.listen(_handleIncomingLink);

  // Tapping the "reset password" email link deep-links back into the app
  // (see kPasswordResetRedirect in auth_service.dart) and Supabase fires
  // this event once it has exchanged the link for a temporary recovery
  // session. That's the cue to show the "set new password" screen.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ResetPasswordView()),
      );
    }
  });

  runApp(const MainApp());
}

Future<void> _handleIncomingLink(Uri uri) async {
  try {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  } catch (e) {
    debugPrint('Deep link session exchange failed: $e');
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const LoginView(),
    );
  }
}
