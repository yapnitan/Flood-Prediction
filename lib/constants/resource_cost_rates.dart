/// Flat per-person resource cost (RM), used to price out a shelter's
/// occupancy headcount into a Resource Consumption Cost figure for the
/// Economic Loss Dashboard (Task/asset report §23/§39). These are simple,
/// transparent placeholder rates (food/water/basic-supplies estimate per
/// person for the duration of the shelter stay) — not sourced from an
/// official cost schedule, since none exists in this project yet.
class ResourceCostRates {
  const ResourceCostRates._();

  static const double perAdult = 50;
  static const double perChild = 35;
  static const double perElderly = 60;
  static const double perInfant = 40;
  static const double perPersonWithDisability = 70;

  static double calculate({
    required int adults,
    required int children,
    required int elderly,
    required int infants,
    required int personsWithDisabilities,
  }) {
    return adults * perAdult +
        children * perChild +
        elderly * perElderly +
        infants * perInfant +
        personsWithDisabilities * perPersonWithDisability;
  }
}
