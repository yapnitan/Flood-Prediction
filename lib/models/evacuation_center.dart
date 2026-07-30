class EvacuationCenter {
  final String id;
  final String name;
  final String state;
  final String district;
  final int capacity;
  final int currentOccupants;
  final String status; // 'Active', 'Standby', 'Full', 'Maintenance'
  final String contactPerson;
  final String contactPhone;
  final double latitude;
  final double longitude;

  const EvacuationCenter({
    required this.id,
    required this.name,
    required this.state,
    required this.district,
    required this.capacity,
    required this.currentOccupants,
    required this.status,
    required this.contactPerson,
    required this.contactPhone,
    required this.latitude,
    required this.longitude,
  });

  int get availableSpace => (capacity - currentOccupants).clamp(0, capacity);
  double get occupancyRate => capacity > 0 ? (currentOccupants / capacity).clamp(0.0, 1.0) : 0.0;

  EvacuationCenter copyWith({
    String? id,
    String? name,
    String? state,
    String? district,
    int? capacity,
    int? currentOccupants,
    String? status,
    String? contactPerson,
    String? contactPhone,
    double? latitude,
    double? longitude,
  }) {
    return EvacuationCenter(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      district: district ?? this.district,
      capacity: capacity ?? this.capacity,
      currentOccupants: currentOccupants ?? this.currentOccupants,
      status: status ?? this.status,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
