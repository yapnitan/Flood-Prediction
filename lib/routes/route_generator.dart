import 'package:flutter/material.dart';

import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/auth/forgot_password_view.dart';
import '../views/auth/verify_email_view.dart';
import '../views/admin/admin_view.dart';
import '../views/admin/repair_request_admin_view.dart';
import '../views/helper/helper_view.dart';
import '../views/user/user_view.dart';
import '../views/user/simulation_list_view.dart';
import '../views/user/create_simulation_view.dart';
import '../views/user/simulation_detail_view.dart';
import '../views/user/simulation_compare_view.dart';
import '../views/user/create_repair_request_view.dart';
import '../views/user/my_repair_requests_view.dart';
import '../views/user/repair_request_detail_view.dart';
import '../views/user/report_history_view.dart';
import '../views/user/planner_dashboard_view.dart';
import '../views/user/checklist_view.dart';
import '../views/user/inventory_view.dart';
import '../views/user/contacts_view.dart';
import '../views/user/pps_map_view.dart';
import '../views/user/my_properties_view.dart';
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
        final args = settings.arguments as CreateSimulationArgs?;
        return MaterialPageRoute(
          builder: (_) => CreateSimulationView(existing: args?.existing),
        );

      case AppRoutes.simulationDetail:
        final args = settings.arguments as SimulationDetailArgs;
        return MaterialPageRoute(
          builder: (_) => SimulationDetailView(
            simulation: args.simulation,
            factors: args.factors,
            recommendations: args.recommendations,
          ),
        );

      case AppRoutes.simulationCompare:
        return MaterialPageRoute(builder: (_) => const SimulationCompareView());

      case AppRoutes.createRepairRequest:
        return MaterialPageRoute(
          builder: (_) => const CreateRepairRequestView(),
        );

      case AppRoutes.myRepairRequests:
        return MaterialPageRoute(builder: (_) => const MyRepairRequestsView());

      case AppRoutes.repairRequestDetail:
        final args = settings.arguments as RepairRequestDetailArgs;
        return MaterialPageRoute(
          builder: (_) => RepairRequestDetailView(requestId: args.requestId),
        );

      case AppRoutes.repairRequestAdmin:
        return MaterialPageRoute(
          builder: (_) => const RepairRequestAdminView(),
        );

      case AppRoutes.reportHistory:
        return MaterialPageRoute(builder: (_) => const ReportHistoryView());

      case AppRoutes.planner:
        return MaterialPageRoute(builder: (_) => const PlannerDashboardView());

      case AppRoutes.checklist:
        return MaterialPageRoute(builder: (_) => const ChecklistView());

      case AppRoutes.inventory:
        return MaterialPageRoute(builder: (_) => const InventoryView());

      case AppRoutes.contacts:
        return MaterialPageRoute(builder: (_) => const ContactsView());

      case AppRoutes.ppsMap:
        return MaterialPageRoute(builder: (_) => const PpsMapView());

      case AppRoutes.myProperties:
        return MaterialPageRoute(builder: (_) => const MyPropertiesView());

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
        return MaterialPageRoute(builder: (_) => const LoginView());
    }
  }
}
