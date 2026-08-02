class AppRoutes {
  const AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  static const String adminHome = '/admin';
  static const String helperHome = '/helper';
  static const String userHome = '/user';

  static const String simulationList = '/simulations';
  static const String createSimulation = '/simulations/create';
  static const String simulationDetail = '/simulations/detail';

  static const String createRepairRequest = '/repair-requests/create';

  static const String personalInformation = '/profile/personal-information';
  static const String notificationSettings = '/profile/notification-settings';
  static const String helpSupport = '/profile/help-support';
  static const String about = '/profile/about';
}
