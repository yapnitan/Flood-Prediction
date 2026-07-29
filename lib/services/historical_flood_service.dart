import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/historical_flood.dart';
import '../utils/geo_utils.dart';
import '../utils/malaysia_geocoding.dart';

/// All Supabase access for the `historical_flood` table.
///
/// This table holds the official JPS/DID historical flood dataset
/// (https://mywater.gov.my/Portal/Modules/HidroMet/Banjir.aspx), imported via
/// [importRecords]. The app never hardcodes historical flood records.
class HistoricalFloodService {
  final supabase = Supabase.instance.client;

  static const String _table = 'historical_flood';
  static const int defaultPageSize = 20;

  /// Filters by any combination of state, district, river basin, flood
  /// cause and flood-date range, with pagination. Pass no filters to
  /// page through the full dataset.
  Future<List<HistoricalFlood>> search({
    String? state,
    String? district,
    String? riverBasin,
    String? floodCause,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    try {
      var query = supabase.from(_table).select();

      if (state != null && state.isNotEmpty) {
        query = query.eq('state', state);
      }
      if (district != null && district.isNotEmpty) {
        query = query.eq('district', district);
      }
      if (riverBasin != null && riverBasin.isNotEmpty) {
        query = query.eq('river_basin', riverBasin);
      }
      if (floodCause != null && floodCause.isNotEmpty) {
        query = query.eq('flood_cause', floodCause);
      }
      if (startDate != null) {
        query = query.gte('flood_date', _dateOnly(startDate));
      }
      if (endDate != null) {
        query = query.lte('flood_date', _dateOnly(endDate));
      }

      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      final response = await query
          .order('flood_date', ascending: false)
          .range(from, to);

      return (response as List)
          .map((row) => HistoricalFlood.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('HistoricalFloodService.search error: $e');
      return [];
    }
  }

  Future<HistoricalFlood?> getById(String id) async {
    try {
      final row = await supabase
          .from(_table)
          .select()
          .eq('id', id)
          .maybeSingle();

      return row != null ? HistoricalFlood.fromJson(row) : null;
    } catch (e) {
      debugPrint('HistoricalFloodService.getById error: $e');
      return null;
    }
  }

  /// Records within [radiusKm] of the given coordinates, nearest first.
  /// Narrows the query with a bounding box, then ranks by exact distance.
  Future<List<HistoricalFlood>> getNearby({
    required double latitude,
    required double longitude,
    double radiusKm = 20,
    int limit = 50,
  }) async {
    try {
      final box = GeoBoundingBox.fromCenter(
        lat: latitude,
        lon: longitude,
        radiusKm: radiusKm,
      );

      final response = await supabase
          .from(_table)
          .select()
          .gte('latitude', box.minLat)
          .lte('latitude', box.maxLat)
          .gte('longitude', box.minLon)
          .lte('longitude', box.maxLon);

      final records = (response as List)
          .map((row) => HistoricalFlood.fromJson(row as Map<String, dynamic>))
          .where((r) => r.latitude != null && r.longitude != null)
          .toList();

      records.sort((a, b) {
        final distA = haversineDistanceKm(
          lat1: latitude,
          lon1: longitude,
          lat2: a.latitude!,
          lon2: a.longitude!,
        );
        final distB = haversineDistanceKm(
          lat1: latitude,
          lon1: longitude,
          lat2: b.latitude!,
          lon2: b.longitude!,
        );
        return distA.compareTo(distB);
      });

      final withinRadius = records.where((r) {
        final dist = haversineDistanceKm(
          lat1: latitude,
          lon1: longitude,
          lat2: r.latitude!,
          lon2: r.longitude!,
        );
        return dist <= radiusKm;
      }).toList();

      return withinRadius.take(limit).toList();
    } catch (e) {
      debugPrint('HistoricalFloodService.getNearby error: $e');
      return [];
    }
  }

  /// Bulk-imports parsed government dataset records into Supabase, in
  /// chunks to stay under request payload limits. Existing rows with a
  /// matching `id` are upserted rather than duplicated.
  ///
  /// The source dataset has no coordinates, so any record missing
  /// latitude/longitude is filled in with an approximate state/district
  /// centroid (see [MalaysiaGeocoder]) before being written.
  Future<int> importRecords(
    List<HistoricalFlood> records, {
    int chunkSize = 500,
  }) async {
    var imported = 0;
    try {
      final geocoded = records.map(_withGeocodedLocation).toList();

      for (var i = 0; i < geocoded.length; i += chunkSize) {
        final chunk = geocoded.sublist(
          i,
          i + chunkSize > geocoded.length ? geocoded.length : i + chunkSize,
        );

        await supabase
            .from(_table)
            .upsert(chunk.map((r) => r.toJson()).toList());

        imported += chunk.length;
      }
      return imported;
    } catch (e) {
      debugPrint('HistoricalFloodService.importRecords error: $e');
      return imported;
    }
  }

  HistoricalFlood _withGeocodedLocation(HistoricalFlood record) {
    if (record.latitude != null && record.longitude != null) return record;

    final coord = MalaysiaGeocoder.centroidFor(
      state: record.state,
      district: record.district,
    );
    if (coord == null) return record;

    return record.copyWith(latitude: coord.$1, longitude: coord.$2);
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;
}
