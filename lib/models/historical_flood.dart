class HistoricalFlood {
  final String? id;
  final String state;
  final String district;
  final String? riverBasin;
  final double? latitude;
  final double? longitude;
  final DateTime floodDate;
  final String floodCause;
  final String source;

  HistoricalFlood({
    this.id,
    required this.state,
    required this.district,
    this.riverBasin,
    this.latitude,
    this.longitude,
    required this.floodDate,
    required this.floodCause,
    this.source = 'JPS/DID',
  });

  factory HistoricalFlood.fromJson(Map<String, dynamic> json) {
    return HistoricalFlood(
      id: json['id'] as String?,
      state: json['state'] as String,
      district: json['district'] as String,
      riverBasin: json['river_basin'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      floodDate: DateTime.parse(json['flood_date'] as String),
      floodCause: json['flood_cause'] as String,
      source: json['source'] as String? ?? 'JPS/DID',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'state': state,
      'district': district,
      'river_basin': riverBasin,
      'latitude': latitude,
      'longitude': longitude,
      'flood_date': floodDate.toIso8601String().split('T').first,
      'flood_cause': floodCause,
      'source': source,
    };
  }

  HistoricalFlood copyWith({double? latitude, double? longitude}) {
    return HistoricalFlood(
      id: id,
      state: state,
      district: district,
      riverBasin: riverBasin,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      floodDate: floodDate,
      floodCause: floodCause,
      source: source,
    );
  }
}
