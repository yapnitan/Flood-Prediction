
class SimulationFactor {
  final String? id;
  final String? simulationId;
  final String factorName;
  final String factorValue;
  final double scoreContribution;

  SimulationFactor({
    this.id,
    this.simulationId,
    required this.factorName,
    required this.factorValue,
    required this.scoreContribution,
  });

  factory SimulationFactor.fromJson(Map<String, dynamic> json) {
    return SimulationFactor(
      id: json['id'] as String?,
      simulationId: json['simulation_id'] as String?,
      factorName: json['factor_name'] as String,
      factorValue: json['factor_value'] as String,
      scoreContribution: (json['score_contribution'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (simulationId != null) 'simulation_id': simulationId,
      'factor_name': factorName,
      'factor_value': factorValue,
      'score_contribution': scoreContribution,
    };
  }

  SimulationFactor copyWith({String? simulationId}) {
    return SimulationFactor(
      id: id,
      simulationId: simulationId ?? this.simulationId,
      factorName: factorName,
      factorValue: factorValue,
      scoreContribution: scoreContribution,
    );
  }
}
