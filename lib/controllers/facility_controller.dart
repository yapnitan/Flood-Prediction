import '../models/facility.dart';
import '../services/facility_service.dart';
import '../utils/geo_utils.dart';

class FacilityController {
  final FacilityService facilityService;

  FacilityController(this.facilityService);

  /// For Admin, full list to manage active and inactive
  Future<List<Facility>> getAllFacilities() {
    return facilityService.getAllFacilities();
  }

  Future<List<Facility>> getAssignableFacilities(String facilityType) {
    return facilityService.getFacilitiesByType(facilityType, activeOnly: true);
  }

  Future<List<FacilityWithDistance>> getAssignableFacilitiesSorted(
    String facilityType, {
    required double lat,
    required double lon,
  }) async {
    final facilities = await getAssignableFacilities(facilityType);
    final withDistance = facilities
        .map((f) => FacilityWithDistance(
              facility: f,
              distanceKm: haversineDistanceKm(lat1: lat, lon1: lon, lat2: f.latitude, lon2: f.longitude),
            ))
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return withDistance;
  }

  Future<Facility?> getFacilityById(String facilityId) {
    return facilityService.getFacilityById(facilityId);
  }

  Future<bool> createFacility(Facility facility) {
    return facilityService.createFacility(facility);
  }

  Future<void> updateFacility(String facilityId, Map<String, dynamic> updates) {
    return facilityService.updateFields(facilityId, updates);
  }

  Future<void> setActive(String facilityId, bool isActive) async {
    await facilityService.updateFields(facilityId, {'is_active': isActive});
  }
}

class FacilityWithDistance {
  const FacilityWithDistance({required this.facility, required this.distanceKm});

  final Facility facility;
  final double distanceKm;
}