
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
    int days = 1,
  }) {
    final perDay = adults * perAdult +
        children * perChild +
        elderly * perElderly +
        infants * perInfant +
        personsWithDisabilities * perPersonWithDisability;
    return perDay * (days < 1 ? 1 : days);
  }
}
