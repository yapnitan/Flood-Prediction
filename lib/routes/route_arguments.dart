import '../models/account.dart';
import '../models/flood_simulation.dart';
import '../models/simulation_factor.dart';

class PersonalInformationArgs {
  final Account account;

  const PersonalInformationArgs(this.account);
}

class NotificationSettingsArgs {
  final Account account;

  const NotificationSettingsArgs(this.account);
}

class CreateSimulationArgs {

  final FloodSimulation? existing;

  const CreateSimulationArgs({this.existing});
}

class SimulationDetailArgs {
  final FloodSimulation simulation;
  final List<SimulationFactor>? factors;
  final List<String>? recommendations;

  const SimulationDetailArgs({
    required this.simulation,
    this.factors,
    this.recommendations,
  });
}

class AssetLossDetailArgs {
  final String reportId;
  const AssetLossDetailArgs({required this.reportId});
}
