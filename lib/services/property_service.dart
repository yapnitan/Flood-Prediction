import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/property.dart';

class PropertyService {
  PropertyService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'property';

  final SupabaseClient _supabase;

  Future<List<Property>> getMyProperties() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _supabase
        .from(_table)
        .select()
        .eq('account_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Property.fromJson(e)).toList();
  }

  Future<Property?> getPropertyById(int propertyId) async {
    final data = await _supabase.from(_table).select().eq('id', propertyId).maybeSingle();
    return data == null ? null : Property.fromJson(data);
  }

  Future<Property?> createProperty(Property property) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('PropertyService.createProperty error: user is not authenticated');
      return null;
    }
    try {
      final inserted = await _supabase
          .from(_table)
          .insert(Property(
            accountId: userId,
            label: property.label,
            address: property.address,
            lat: property.lat,
            lng: property.lng,
            state: property.state,
            district: property.district,
            postcode: property.postcode,
            propertyType: property.propertyType,
            floors: property.floors,
            estimatedValue: property.estimatedValue,
          ).toJson())
          .select()
          .single();
      return Property.fromJson(inserted);
    } catch (error) {
      debugPrint('PropertyService.createProperty error: $error');
      return null;
    }
  }

  Future<Property?> updateProperty(int propertyId, Property property) async {
    try {
      final updated = await _supabase
          .from(_table)
          .update(property.toJson())
          .eq('id', propertyId)
          .select()
          .single();
      return Property.fromJson(updated);
    } catch (error) {
      debugPrint('PropertyService.updateProperty error: $error');
      return null;
    }
  }

  /// Returns a user-facing error message on failure (most commonly the
  /// property still being referenced by an asset loss report — RESTRICTed
  /// at the DB level so it can't be silently orphaned, see
  /// 0028_restrict_property_deletion.sql), or null on success.
  Future<String?> deleteProperty(int propertyId) async {
    try {
      await _supabase.from(_table).delete().eq('id', propertyId);
      return null;
    } on PostgrestException catch (e) {
      debugPrint('PropertyService.deleteProperty error: $e');
      if (e.code == '23503') {
        return 'This property has asset loss reports linked to it and cannot be deleted.';
      }
      return 'Could not delete this property. Please try again.';
    } catch (error) {
      debugPrint('PropertyService.deleteProperty error: $error');
      return 'Could not delete this property. Please try again.';
    }
  }
}
