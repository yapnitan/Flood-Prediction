import 'package:flutter/material.dart';

import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/auth/forgot_password_view.dart';
import '../views/auth/verify_email_view.dart';
import '../views/admin/admin_view.dart';
import '../views/helper/helper_view.dart';
import '../views/user/user_view.dart';
import '../views/user/simulation_list_view.dart';
import '../views/user/create_simulation_view.dart';
import '../views/user/simulation_detail_view.dart';
import '../views/user/create_repair_request_view.dart';
import '../views/shared/personal_information_view.dart';
import '../views/shared/change_password_view.dart';
import '../views/shared/notification_settings_view.dart';
import '../views/shared/help_support_view.dart';
import '../views/shared/about_view.dart';
import 'app_routes.dart';
import 'route_arguments.dart';

class RouteGenerator {
  const RouteGenerator._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginView());

      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegistrationPage());

      case AppRoutes.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());

      case AppRoutes.verifyEmail:
        return MaterialPageRoute(builder: (_) => const VerifyEmailPage());

      case AppRoutes.adminHome:
        return MaterialPageRoute(builder: (_) => const AdminHome());

      case AppRoutes.helperHome:
        return MaterialPageRoute(builder: (_) => const HelperHome());

      case AppRoutes.userHome:
        return MaterialPageRoute(builder: (_) => const UserHome());

      case AppRoutes.simulationList:
        return MaterialPageRoute(builder: (_) => const SimulationListView());

      case AppRoutes.createSimulation:
        return MaterialPageRoute(builder: (_) => const CreateSimulationView());

      case AppRoutes.simulationDetail:
        final args = settings.arguments as SimulationDetailArgs;
        return MaterialPageRoute(
          builder: (_) => SimulationDetailView(
            simulation: args.simulation,
            factors: args.factors,
            recommendations: args.recommendations,
          ),
        );

      case AppRoutes.createRepairRequest:
        return MaterialPageRoute(builder: (_) => const CreateRepairRequestView());

      case AppRoutes.personalInformation:
        final args = settings.arguments as PersonalInformationArgs;
        return MaterialPageRoute(
          builder: (_) => PersonalInformationView(account: args.account),
        );

      case AppRoutes.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordView());

      case AppRoutes.notificationSettings:
        final args = settings.arguments as NotificationSettingsArgs;
        return MaterialPageRoute(
          builder: (_) => NotificationSettingsView(account: args.account),
        );

      case AppRoutes.helpSupport:
        return MaterialPageRoute(builder: (_) => const HelpSupportView());

      case AppRoutes.about:
        return MaterialPageRoute(builder: (_) => const AboutView());

      default:
        return MaterialPageRoute(
          builder: (_) => const LoginView(),
        );
    }
  }
}