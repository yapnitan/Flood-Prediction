import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checklist_item.dart';
import '../models/emergency_checklist.dart';
import '../models/emergency_contact.dart';
import '../models/inventory_item.dart';
import 'connectivity_service.dart';
import 'offline_sync_service.dart';

class PlannerService {
  PlannerService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  static const _checklistTable = 'emergency_checklist';
  static const _checklistItemTable = 'checklist_item';
  static const _inventoryTable = 'inventory_item';
  static const _contactTable = 'emergency_contact';

  final SupabaseClient _supabase;

  Future<List<T>> _cachedList<T>(
    String cacheKey,
    Future<List<Map<String, dynamic>>> Function() fetch,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (!ConnectivityService.instance.isOnline) {
      final cached = await OfflineSyncService.instance.getCachedList(cacheKey);
      return (cached ?? []).map(fromJson).toList();
    }
    try {
      final rows = await fetch();
      await OfflineSyncService.instance.cacheList(cacheKey, rows);
      return rows.map(fromJson).toList();
    } catch (error) {
      debugPrint('PlannerService: fetch for "$cacheKey" failed, falling back to cache: $error');
      final cached = await OfflineSyncService.instance.getCachedList(cacheKey);
      return (cached ?? []).map(fromJson).toList();
    }
  }

  Future<bool> _write({
    required String table,
    required String opType,
    String? rowId,
    required Map<String, dynamic> payload,
    required String cacheKey,
    String? baseUpdatedAt,
  }) async {
    if (!ConnectivityService.instance.isOnline) {
      final localId = rowId ?? 'local_${DateTime.now().microsecondsSinceEpoch}';
      await OfflineSyncService.instance.queueOperation(
        table: table,
        opType: opType,
        rowId: rowId,
        payload: payload,
        baseUpdatedAt: baseUpdatedAt,
      );
      await OfflineSyncService.instance.applyOptimisticChange(
        cacheKey,
        opType: opType,
        rowId: rowId ?? localId,
        payload: opType == 'insert' ? {...payload, 'id': localId} : payload,
      );
      return true;
    }
    try {
      switch (opType) {
        case 'insert':
          await _supabase.from(table).insert(payload);
        case 'update':
          await _supabase.from(table).update(payload).eq('id', rowId!);
        case 'delete':
          await _supabase.from(table).delete().eq('id', rowId!);
      }
      return true;
    } catch (error) {
      debugPrint('PlannerService: $opType on $table failed: $error');
      return false;
    }
  }

  Future<List<EmergencyChecklist>> getChecklists(String accountId) {
    return _cachedList(
      'planner_checklists_$accountId',
      () async {
        final data = await _supabase
            .from(_checklistTable)
            .select()
            .eq('account_id', accountId)
            .order('created_at');
        return List<Map<String, dynamic>>.from(data);
      },
      EmergencyChecklist.fromJson,
    );
  }

  Future<EmergencyChecklist?> createChecklist(EmergencyChecklist checklist) async {
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('PlannerService.createChecklist: offline, new checklists need a connection.');
      return null;
    }
    try {
      final row = await _supabase.from(_checklistTable).insert(checklist.toJson()).select().single();
      return EmergencyChecklist.fromJson(row);
    } catch (error) {
      debugPrint('PlannerService.createChecklist error: $error');
      return null;
    }
  }

  Future<bool> renameChecklist(String id, String title, String accountId) {
    return _write(
      table: _checklistTable,
      opType: 'update',
      rowId: id,
      payload: {'title': title},
      cacheKey: 'planner_checklists_$accountId',
    );
  }

  Future<bool> deleteChecklist(String id, String accountId) {
    return _write(
      table: _checklistTable,
      opType: 'delete',
      rowId: id,
      payload: const {},
      cacheKey: 'planner_checklists_$accountId',
    );
  }

  Future<List<ChecklistItem>> getItems(String checklistId) {
    return _cachedList(
      'planner_items_$checklistId',
      () async {
        final data = await _supabase
            .from(_checklistItemTable)
            .select()
            .eq('checklist_id', checklistId)
            .order('sort_order')
            .order('created_at');
        return List<Map<String, dynamic>>.from(data);
      },
      ChecklistItem.fromJson,
    );
  }

  Future<List<ChecklistItem>> getAllItems(String accountId) {
    return _cachedList(
      'planner_all_items_$accountId',
      () async {
        final data = await _supabase
            .from(_checklistItemTable)
            .select('*, emergency_checklist!inner(account_id)')
            .eq('emergency_checklist.account_id', accountId);
        return List<Map<String, dynamic>>.from(data);
      },
      ChecklistItem.fromJson,
    );
  }

  Future<bool> addItem(ChecklistItem item) {
    return _write(
      table: _checklistItemTable,
      opType: 'insert',
      payload: item.toJson(),
      cacheKey: 'planner_items_${item.checklistId}',
    );
  }

  Future<bool> setItemChecked(String id, bool checked, String checklistId) {
    return _write(
      table: _checklistItemTable,
      opType: 'update',
      rowId: id,
      payload: {'is_checked': checked},
      cacheKey: 'planner_items_$checklistId',
    );
  }

  Future<bool> deleteItem(String id, String checklistId) {
    return _write(
      table: _checklistItemTable,
      opType: 'delete',
      rowId: id,
      payload: const {},
      cacheKey: 'planner_items_$checklistId',
    );
  }


  Future<List<InventoryItem>> getInventory(String accountId) {
    return _cachedList(
      'planner_inventory_$accountId',
      () async {
        final data = await _supabase
            .from(_inventoryTable)
            .select()
            .eq('account_id', accountId)
            .order('name');
        return List<Map<String, dynamic>>.from(data);
      },
      InventoryItem.fromJson,
    );
  }

  Future<bool> createInventoryItem(InventoryItem item) {
    return _write(
      table: _inventoryTable,
      opType: 'insert',
      payload: item.toJson(),
      cacheKey: 'planner_inventory_${item.accountId}',
    );
  }

  Future<bool> updateInventoryItem(String id, Map<String, dynamic> updates, String accountId) {
    return _write(
      table: _inventoryTable,
      opType: 'update',
      rowId: id,
      payload: updates,
      cacheKey: 'planner_inventory_$accountId',
    );
  }

  Future<bool> deleteInventoryItem(String id, String accountId) {
    return _write(
      table: _inventoryTable,
      opType: 'delete',
      rowId: id,
      payload: const {},
      cacheKey: 'planner_inventory_$accountId',
    );
  }


  Future<List<EmergencyContact>> getContacts(String accountId) {
    return _cachedList(
      'planner_contacts_$accountId',
      () async {
        final data = await _supabase
            .from(_contactTable)
            .select()
            .eq('account_id', accountId)
            .order('name');
        return List<Map<String, dynamic>>.from(data);
      },
      EmergencyContact.fromJson,
    );
  }

  Future<bool> createContact(EmergencyContact contact) {
    return _write(
      table: _contactTable,
      opType: 'insert',
      payload: contact.toJson(),
      cacheKey: 'planner_contacts_${contact.accountId}',
    );
  }

  Future<bool> updateContact(String id, Map<String, dynamic> updates, String accountId) {
    return _write(
      table: _contactTable,
      opType: 'update',
      rowId: id,
      payload: updates,
      cacheKey: 'planner_contacts_$accountId',
    );
  }

  Future<bool> deleteContact(String id, String accountId) {
    return _write(
      table: _contactTable,
      opType: 'delete',
      rowId: id,
      payload: const {},
      cacheKey: 'planner_contacts_$accountId',
    );
  }
}
