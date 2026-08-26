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
import '../views/user/simulation_compare_view.dart';
import '../views/user/create_asset_loss_report_view.dart';
import '../views/user/my_asset_loss_reports_view.dart';
import '../views/user/asset_loss_report_detail_view.dart';
import '../views/user/report_history_view.dart';
import '../views/user/planner_dashboard_view.dart';
import '../views/user/checklist_view.dart';
import '../views/user/inventory_view.dart';
import '../views/user/contacts_view.dart';
import '../views/user/pps_map_view.dart';
import '../views/user/my_properties_view.dart';
import '../views/admin/economic_loss_dashboard_view.dart';
import '../views/admin/flood_incident_admin_view.dart';
import '../views/admin/helper_assignment_admin_view.dart';
import '../views/helper/shelter_occupancy_view.dart';
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

      case AppRoutes.assetLossCreate:
        return MaterialPageRoute(
          builder: (_) => const CreateAssetLossReportView(),
        );

      case AppRoutes.myAssetLossReports:
        return MaterialPageRoute(builder: (_) => const MyAssetLossReportsView());

      case AppRoutes.assetLossDetail:
        final args = settings.arguments as AssetLossDetailArgs;
        return MaterialPageRoute(
          builder: (_) => AssetLossReportDetailView(reportId: args.reportId),
        );

      case AppRoutes.economicLossDashboard:
        return MaterialPageRoute(builder: (_) => const EconomicLossDashboardView());

      case AppRoutes.floodIncidentAdmin:
        return MaterialPageRoute(builder: (_) => const FloodIncidentAdminView());

      case AppRoutes.helperAssignmentAdmin:
        return MaterialPageRoute(builder: (_) => const HelperAssignmentAdminView());

      case AppRoutes.shelterOccupancy:
        return MaterialPageRoute(builder: (_) => const ShelterOccupancyView());

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
