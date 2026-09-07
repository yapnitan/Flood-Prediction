import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connectivity_service.dart';

/// Task 14 offline support — a small local SQLite-backed layer that
/// individual services opt into for two things:
///
/// 1. **Read caching**: the last-fetched rows for a given key, so a list
///    screen still has something to show when offline instead of an empty
///    "could not load" state.
/// 2. **Write queueing**: writes made while offline are recorded here and
///    replayed against Supabase once [ConnectivityService] reports back
///    online, in the order they were queued. Conflict resolution is
///    last-write-wins by `updated_at`: if the server's row changed more
///    recently than the snapshot an offline edit was based on, the queued
///    write is dropped rather than silently overwriting someone else's
///    change.
///
/// Deliberately generic (keyed by string, storing/replaying raw JSON maps)
/// rather than one bespoke table per model — the offline behavior is the
/// same shape for every entity that uses it (see PlannerService,
/// FloodReportService, FloodSimulationService for callers), so this is one
/// reusable layer other services call into instead of each reimplementing
/// their own cache/queue.
class OfflineSyncService {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  Database? _db;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isReplaying = false;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'flood_watch_offline.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          create table cache (
            cache_key text primary key,
            data text not null,
            cached_at text not null
          )
        ''');
        await db.execute('''
          create table pending_ops (
            id integer primary key autoincrement,
            table_name text not null,
            op_type text not null,
            row_id text,
            payload text not null,
            base_updated_at text,
            created_at text not null
          )
        ''');
      },
    );
    _db = db;
    return db;
  }

  Future<void> initialize() async {
    await _database;
    _connectivitySubscription = ConnectivityService.instance.onStatusChange.listen((online) {
      if (online) replayPendingOperations();
    });
    if (ConnectivityService.instance.isOnline) {
      unawaited(replayPendingOperations());
    }
  }

  // ---- Read cache ----

  Future<void> cacheList(String key, List<Map<String, dynamic>> rows) async {
    final db = await _database;
    await db.insert(
      'cache',
      {
        'cache_key': key,
        'data': jsonEncode(rows),
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>?> getCachedList(String key) async {
    final db = await _database;
    final rows = await db.query('cache', where: 'cache_key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(rows.first['data'] as String) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Applies an offline write directly to the cached list too, so a screen
  /// reading from cache while still offline reflects the change
  /// immediately instead of only after the next successful sync.
  Future<void> applyOptimisticChange(
    String cacheKey, {
    required String opType,
    String? rowId,
    Map<String, dynamic>? payload,
  }) async {
    final current = await getCachedList(cacheKey) ?? [];
    switch (opType) {
      case 'insert':
        current.add(payload!);
        break;
      case 'update':
        final index = current.indexWhere((row) => row['id'] == rowId);
        if (index != -1) current[index] = {...current[index], ...?payload};
        break;
      case 'delete':
        current.removeWhere((row) => row['id'] == rowId);
        break;
    }
    await cacheList(cacheKey, current);
  }

  // ---- Write queue ----

  Future<void> queueOperation({
    required String table,
    required String opType,
    String? rowId,
    required Map<String, dynamic> payload,
    String? baseUpdatedAt,
  }) async {
    final db = await _database;
    await db.insert('pending_ops', {
      'table_name': table,
      'op_type': opType,
      'row_id': rowId,
      'payload': jsonEncode(payload),
      'base_updated_at': baseUpdatedAt,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> pendingOperationCount() async {
    final db = await _database;
    final result = await db.rawQuery('select count(*) as c from pending_ops');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Replays queued writes in order against Supabase. Stops at the first
  /// failure (rather than skipping it) so a later op can't land out of
  /// order ahead of one still stuck — it'll pick back up from there on the
  /// next connectivity transition.
  Future<void> replayPendingOperations() async {
    if (_isReplaying || !ConnectivityService.instance.isOnline) return;
    _isReplaying = true;
    try {
      final db = await _database;
      final supabase = Supabase.instance.client;
      final ops = await db.query('pending_ops', orderBy: 'id');

      for (final op in ops) {
        final id = op['id'] as int;
        final table = op['table_name'] as String;
        final opType = op['op_type'] as String;
        final rowId = op['row_id'] as String?;
        final payload = jsonDecode(op['payload'] as String) as Map<String, dynamic>;
        final baseUpdatedAt = op['base_updated_at'] as String?;

        try {
          switch (opType) {
            case 'insert':
              await supabase.from(table).insert(payload);
            case 'update':
              if (rowId == null) break;
              if (baseUpdatedAt != null &&
                  await _serverRowChangedSince(supabase, table, rowId, baseUpdatedAt)) {
                debugPrint(
                  'OfflineSyncService: dropping stale queued update for $table/$rowId '
                  '— server row changed since this offline edit was made.',
                );
              } else {
                await supabase.from(table).update(payload).eq('id', rowId);
              }
            case 'delete':
              if (rowId == null) break;
              await supabase.from(table).delete().eq('id', rowId);
          }
          await db.delete('pending_ops', where: 'id = ?', whereArgs: [id]);
        } catch (error) {
          debugPrint('OfflineSyncService.replayPendingOperations: op $id failed, will retry later: $error');
          break;
        }
      }
    } finally {
      _isReplaying = false;
    }
  }

  Future<bool> _serverRowChangedSince(
    SupabaseClient supabase,
    String table,
    String rowId,
    String baseUpdatedAt,
  ) async {
    try {
      final row = await supabase.from(table).select('updated_at').eq('id', rowId).maybeSingle();
      final serverUpdatedAt = row?['updated_at'] as String?;
      if (serverUpdatedAt == null) return false;
      return DateTime.parse(serverUpdatedAt).isAfter(DateTime.parse(baseUpdatedAt));
    } catch (_) {
      // If we can't tell, don't block the write on it.
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
