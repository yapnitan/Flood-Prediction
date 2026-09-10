import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/property.dart';

class PropertyService {
  PropertyService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const _table = 'property';

  final SupabaseClient _supabase;

  Future<List<Property>> getMyProperties({bool includeArchived = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    var query = _supabase.from(_table).select().eq('account_id', userId);
    if (!includeArchived) {
      query = query.isFilter('archived_at', null);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Property.fromJson(e)).toList();
  }

  Future<Property?> getPropertyById(int propertyId) async {
    final data = await _supabase.from(_table).select().eq('id', propertyId).maybeSingle();
    return data == null ? null : Property.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getStateDistrictPairs() async {
    try {
      final data = await _supabase.from(_table).select('state, district');
      return List<Map<String, dynamic>>.from(data as List);
    } catch (error) {
      debugPrint('PropertyService.getStateDistrictPairs error: $error');
      return [];
    }
  }

  Future<bool> restoreProperty(int propertyId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final rows = await _supabase
          .from(_table)
          .update({'archived_at': null})
          .eq('id', propertyId)
          .eq('account_id', userId)
          .select();
      return (rows as List).isNotEmpty;
    } catch (error) {
      debugPrint('PropertyService.restoreProperty error: $error');
      return false;
    }
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

  Future<({bool changed, String? message})> deleteProperty(int propertyId) async {
    try {
      final rows =
          await _supabase.from(_table).delete().eq('id', propertyId).select();
      if ((rows as List).isEmpty) {
        debugPrint('PropertyService.deleteProperty: 0 rows deleted for $propertyId');
        return (
          changed: false,
          message: 'Could not delete this property. Please try again.',
        );
      }
      return (changed: true, message: null);
    } on PostgrestException catch (e) {
      debugPrint('PropertyService.deleteProperty error: $e');
      if (e.code == '23503') {
        try {
          await _supabase.from(_table).update({
            'archived_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', propertyId);
          return (
            changed: true,
            message: "This address is linked to asset-loss reports, so it's "
                'been archived (removed from your list) instead of deleted.',
          );
        } catch (archiveError) {
          debugPrint(
            'PropertyService.deleteProperty archive fallback error: $archiveError',
          );
          return (
            changed: false,
            message:
                'This property has asset loss reports linked to it and cannot be removed.',
          );
        }
      }
      return (
        changed: false,
        message: 'Could not delete this property. Please try again.',
      );
    } catch (error) {
      debugPrint('PropertyService.deleteProperty error: $error');
      return (
        changed: false,
        message: 'Could not delete this property. Please try again.',
      );
    }
  }
}
