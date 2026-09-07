class FloodIncident {
  const FloodIncident({
    this.id,
    required this.name,
    this.description,
    required this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  final String? id;
  final String name;
  final String? description;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  bool get isActive => endedAt == null;

  factory FloodIncident.fromJson(Map<String, dynamic> json) => FloodIncident(
    id: json['id'] as String?,
    name: json['name'] as String,
    description: json['description'] as String?,
    startedAt: DateTime.parse(json['started_at'] as String),
    endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'started_at': startedAt.toIso8601String().split('T').first,
    'ended_at': endedAt?.toIso8601String().split('T').first,
  };
}
