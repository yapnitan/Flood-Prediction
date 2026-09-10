import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connectivity_service.dart';
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
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
