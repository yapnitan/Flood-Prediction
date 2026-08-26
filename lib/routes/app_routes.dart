class AppRoutes {
  const AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String verifyEmail = '/verify-email';

  static const String adminHome = '/admin';
  static const String helperHome = '/helper';
  static const String userHome = '/user';

  static const String simulationList = '/simulations';
  static const String createSimulation = '/simulations/create';
  static const String simulationDetail = '/simulations/detail';
  static const String simulationCompare = '/simulations/compare';

  static const String assetLossCreate = '/asset-loss/create';
  static const String myAssetLossReports = '/asset-loss/mine';
  static const String assetLossDetail = '/asset-loss/detail';
  static const String assetLossAdmin = '/admin/asset-loss';
  static const String economicLossDashboard = '/admin/economic-loss';
  static const String floodIncidentAdmin = '/admin/flood-incidents';
  static const String helperAssignmentAdmin = '/admin/helper-assignments';
  static const String shelterOccupancy = '/helper/shelter-occupancy';

  static const String reportHistory = '/reports/mine';

  static const String planner = '/planner';
  static const String checklist = '/planner/checklist';
  static const String inventory = '/planner/inventory';
  static const String contacts = '/planner/contacts';
  static const String ppsMap = '/planner/pps-map';

  static const String myProperties = '/profile/my-properties';
  static const String personalInformation = '/profile/personal-information';
  static const String changePassword = '/profile/change-password';
  static const String notificationSettings = '/profile/notification-settings';
  static const String helpSupport = '/profile/help-support';
  static const String about = '/profile/about';
}
