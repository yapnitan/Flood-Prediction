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
            address: property.address,
            lat: property.lat,
            lng: property.lng,
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
}
