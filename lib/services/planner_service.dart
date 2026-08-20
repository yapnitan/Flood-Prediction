import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checklist_item.dart';
import '../models/emergency_checklist.dart';
import '../models/emergency_contact.dart';
import '../models/inventory_item.dart';

/// All Supabase access for Module 3 (Evacuation & Inventory Planner) —
/// checklists/items, inventory, and emergency contacts. One service per
/// CLAUDE.md's naming (`PlannerService`), covering all four tables since
/// they're simple, closely-related, account-scoped CRUD — same rationale
/// as FacilityService covering one table's full CRUD in one place.
class PlannerService {
  PlannerService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  static const _checklistTable = 'emergency_checklist';
  static const _checklistItemTable = 'checklist_item';
  static const _inventoryTable = 'inventory_item';
  static const _contactTable = 'emergency_contact';

  final SupabaseClient _supabase;

  // ---- Checklists ----

  Future<List<EmergencyChecklist>> getChecklists(String accountId) async {
    final data = await _supabase
        .from(_checklistTable)
        .select()
        .eq('account_id', accountId)
        .order('created_at');
    return (data as List).map((e) => EmergencyChecklist.fromJson(e)).toList();
  }

  Future<EmergencyChecklist?> createChecklist(EmergencyChecklist checklist) async {
    try {
      final row = await _supabase.from(_checklistTable).insert(checklist.toJson()).select().single();
      return EmergencyChecklist.fromJson(row);
    } catch (error) {
      debugPrint('PlannerService.createChecklist error: $error');
      return null;
    }
  }

  Future<bool> renameChecklist(String id, String title) async {
    try {
      await _supabase.from(_checklistTable).update({'title': title}).eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.renameChecklist error: $error');
      return false;
    }
  }

  Future<bool> deleteChecklist(String id) async {
    try {
      await _supabase.from(_checklistTable).delete().eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.deleteChecklist error: $error');
      return false;
    }
  }

  // ---- Checklist items ----

  Future<List<ChecklistItem>> getItems(String checklistId) async {
    final data = await _supabase
        .from(_checklistItemTable)
        .select()
        .eq('checklist_id', checklistId)
        .order('sort_order')
        .order('created_at');
    return (data as List).map((e) => ChecklistItem.fromJson(e)).toList();
  }

  /// All items across all of [accountId]'s checklists — used to compute
  /// overall preparation progress without N+1-fetching per checklist.
  Future<List<ChecklistItem>> getAllItems(String accountId) async {
    final data = await _supabase
        .from(_checklistItemTable)
        .select('*, emergency_checklist!inner(account_id)')
        .eq('emergency_checklist.account_id', accountId);
    return (data as List).map((e) => ChecklistItem.fromJson(e)).toList();
  }

  Future<bool> addItem(ChecklistItem item) async {
    try {
      await _supabase.from(_checklistItemTable).insert(item.toJson());
      return true;
    } catch (error) {
      debugPrint('PlannerService.addItem error: $error');
      return false;
    }
  }

  Future<bool> setItemChecked(String id, bool checked) async {
    try {
      await _supabase.from(_checklistItemTable).update({'is_checked': checked}).eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.setItemChecked error: $error');
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await _supabase.from(_checklistItemTable).delete().eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.deleteItem error: $error');
      return false;
    }
  }

  // ---- Inventory ----

  Future<List<InventoryItem>> getInventory(String accountId) async {
    final data = await _supabase
        .from(_inventoryTable)
        .select()
        .eq('account_id', accountId)
        .order('name');
    return (data as List).map((e) => InventoryItem.fromJson(e)).toList();
  }

  Future<bool> createInventoryItem(InventoryItem item) async {
    try {
      await _supabase.from(_inventoryTable).insert(item.toJson());
      return true;
    } catch (error) {
      debugPrint('PlannerService.createInventoryItem error: $error');
      return false;
    }
  }

  Future<bool> updateInventoryItem(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.from(_inventoryTable).update(updates).eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.updateInventoryItem error: $error');
      return false;
    }
  }

  Future<bool> deleteInventoryItem(String id) async {
    try {
      await _supabase.from(_inventoryTable).delete().eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.deleteInventoryItem error: $error');
      return false;
    }
  }

  // ---- Emergency contacts ----

  Future<List<EmergencyContact>> getContacts(String accountId) async {
    final data = await _supabase
        .from(_contactTable)
        .select()
        .eq('account_id', accountId)
        .order('name');
    return (data as List).map((e) => EmergencyContact.fromJson(e)).toList();
  }

  Future<bool> createContact(EmergencyContact contact) async {
    try {
      await _supabase.from(_contactTable).insert(contact.toJson());
      return true;
    } catch (error) {
      debugPrint('PlannerService.createContact error: $error');
      return false;
    }
  }

  Future<bool> updateContact(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.from(_contactTable).update(updates).eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.updateContact error: $error');
      return false;
    }
  }

  Future<bool> deleteContact(String id) async {
    try {
      await _supabase.from(_contactTable).delete().eq('id', id);
      return true;
    } catch (error) {
      debugPrint('PlannerService.deleteContact error: $error');
      return false;
    }
  }
}
