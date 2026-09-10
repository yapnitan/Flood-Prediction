import '../models/property.dart';
import '../services/property_service.dart';

class PropertyController {
  final PropertyService propertyService;

  PropertyController(this.propertyService);

  Future<List<Property>> getMyProperties({bool includeArchived = false}) =>
      propertyService.getMyProperties(includeArchived: includeArchived);

  Future<Property?> getPropertyById(int propertyId) => propertyService.getPropertyById(propertyId);

  Future<Property?> createProperty(Property property) => propertyService.createProperty(property);

  Future<Property?> updateProperty(int propertyId, Property property) =>
      propertyService.updateProperty(propertyId, property);

  Future<({bool changed, String? message})> deleteProperty(int propertyId) =>
      propertyService.deleteProperty(propertyId);

  Future<bool> restoreProperty(int propertyId) =>
      propertyService.restoreProperty(propertyId);

  Future<List<Map<String, dynamic>>> getStateDistrictPairs() =>
      propertyService.getStateDistrictPairs();
}
