import '../constants/resource_cost_rates.dart';

class ShelterOccupancyReport {
  const ShelterOccupancyReport({
    this.id,
    required this.facilityId,
    this.recordedBy,
    required this.adults,
    required this.children,
    required this.elderly,
    required this.infants,
    required this.personsWithDisabilities,
    this.days = 1,
    this.totalVictims,
    this.resourceCost,
    this.recordedAt,
  });

  final String? id;
  final String facilityId;
  final String? recordedBy;
  final int adults;
  final int children;
  final int elderly;
  final int infants;
  final int personsWithDisabilities;

  /// How many days occupants are expected to stay — multiplies the per-day
  /// resource rates.
  final int days;
  final int? totalVictims;
  final double? resourceCost;
  final DateTime? recordedAt;

  int get headcount =>
      adults + children + elderly + infants + personsWithDisabilities;

  double get calculatedResourceCost => ResourceCostRates.calculate(
        adults: adults,
        children: children,
        elderly: elderly,
        infants: infants,
        personsWithDisabilities: personsWithDisabilities,
        days: days,
      );

  factory ShelterOccupancyReport.fromJson(Map<String, dynamic> json) => ShelterOccupancyReport(
    id: json['id'] as String?,
    facilityId: json['facility_id'] as String,
    recordedBy: json['recorded_by'] as String?,
    adults: json['adults'] as int,
    children: json['children'] as int,
    elderly: json['elderly'] as int,
    infants: json['infants'] as int,
    personsWithDisabilities: json['persons_with_disabilities'] as int,
    days: json['days'] as int? ?? 1,
    totalVictims: json['total_victims'] as int?,
    resourceCost: (json['resource_cost'] as num?)?.toDouble(),
    recordedAt: json['recorded_at'] != null ? DateTime.parse(json['recorded_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'facility_id': facilityId,
    'recorded_by': recordedBy,
    'adults': adults,
    'children': children,
    'elderly': elderly,
    'infants': infants,
    'persons_with_disabilities': personsWithDisabilities,
    'days': days,
    'resource_cost': calculatedResourceCost,
  };
}
