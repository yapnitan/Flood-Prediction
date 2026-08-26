import '../models/account.dart';
import '../models/flood_simulation.dart';
import '../models/simulation_factor.dart';

/// Argument bundles for routes that need more than a route name to build
/// their screen. Plain Navigator named routes only pass a single
/// `Object? arguments` value per push, so multi-field payloads (e.g. a
/// pre-computed simulation result plus its factors) are grouped into one
/// of these rather than pushed as separate positional values.

class PersonalInformationArgs {
  final Account account;

  const PersonalInformationArgs(this.account);
}

class NotificationSettingsArgs {
  final Account account;

  const NotificationSettingsArgs(this.account);
}

class CreateSimulationArgs {
  /// When set, the form opens pre-filled for editing this simulation
  /// instead of starting a new one.
  final FloodSimulation? existing;

  const CreateSimulationArgs({this.existing});
}

class SimulationDetailArgs {
  final FloodSimulation simulation;

  /// Only set right after running a brand-new assessment, where the
  /// caller already has these in memory. Null when opened from the
  /// simulation list instead, in which case the detail view fetches them.
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
