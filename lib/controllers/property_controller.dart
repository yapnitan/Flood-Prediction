import '../models/property.dart';
import '../services/property_service.dart';

class PropertyController {
  final PropertyService propertyService;

  PropertyController(this.propertyService);

  Future<List<Property>> getMyProperties() => propertyService.getMyProperties();

  Future<Property?> getPropertyById(int propertyId) => propertyService.getPropertyById(propertyId);

  Future<Property?> createProperty(Property property) => propertyService.createProperty(property);

  Future<Property?> updateProperty(int propertyId, Property property) =>
      propertyService.updateProperty(propertyId, property);

  Future<String?> deleteProperty(int propertyId) => propertyService.deleteProperty(propertyId);
}
