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
      // Only the form-editable fields — never `account_id` (immutable; sending
      // it as null would orphan the row and fail the RLS `with check`),
      // `id`, `created_at`, or `risk_level` (owned by the risk simulator).
      final payload = <String, dynamic>{
        'label': property.label,
        'address': property.address,
        'lat': property.lat,
        'lng': property.lng,
        'state': property.state,
        'district': property.district,
        'postcode': property.postcode,
        'property_type': property.propertyType,
        'floors': property.floors,
        'estimated_value': property.estimatedValue,
      };
      final updated = await _supabase
          .from(_table)
          .update(payload)
          .eq('id', propertyId)
          .select()
          .maybeSingle();
      if (updated == null) {
        debugPrint(
          'PropertyService.updateProperty: 0 rows updated for $propertyId — '
          'RLS "Users manage their own properties" policy missing (migration '
          '0014) or the property is not yours.',
        );
        return null;
      }
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
      final rows =
          await _supabase.from(_table).delete().eq('id', propertyId).select();
      if ((rows as List).isEmpty) {
        debugPrint('PropertyService.deleteProperty: 0 rows deleted for $propertyId');
        return 'Could not delete this property. Please try again.';
      }
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
