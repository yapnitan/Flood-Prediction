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

  static const String createRepairRequest = '/repair-requests/create';
  static const String myRepairRequests = '/repair-requests/mine';
  static const String repairRequestDetail = '/repair-requests/detail';
  static const String repairRequestAdmin = '/admin/repair-requests';

  static const String reportHistory = '/reports/mine';

  static const String personalInformation = '/profile/personal-information';
  static const String changePassword = '/profile/change-password';
  static const String notificationSettings = '/profile/notification-settings';
  static const String helpSupport = '/profile/help-support';
  static const String about = '/profile/about';
}
