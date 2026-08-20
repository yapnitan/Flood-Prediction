import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checklist_item.dart';
import '../models/emergency_checklist.dart';
import '../models/emergency_contact.dart';
import '../models/inventory_item.dart';
import '../services/planner_service.dart';

class PlannerController {
  final PlannerService plannerService;

  PlannerController(this.plannerService);

  String? get _accountId => Supabase.instance.client.auth.currentUser?.id;

  // ---- Checklists ----

  Future<List<EmergencyChecklist>> getChecklists() async {
    final accountId = _accountId;
    if (accountId == null) return [];
    return plannerService.getChecklists(accountId);
  }

  Future<EmergencyChecklist?> createChecklist(String title) {
    final accountId = _accountId;
    if (accountId == null) return Future.value(null);
    return plannerService.createChecklist(EmergencyChecklist(accountId: accountId, title: title));
  }

  Future<bool> renameChecklist(String id, String title) => plannerService.renameChecklist(id, title);

  Future<bool> deleteChecklist(String id) => plannerService.deleteChecklist(id);

  // ---- Checklist items ----

  Future<List<ChecklistItem>> getItems(String checklistId) => plannerService.getItems(checklistId);

  Future<bool> addItem(String checklistId, String label) {
    return plannerService.addItem(ChecklistItem(checklistId: checklistId, label: label));
  }

  Future<bool> setItemChecked(String id, bool checked) => plannerService.setItemChecked(id, checked);

  Future<bool> deleteItem(String id) => plannerService.deleteItem(id);

  /// Preparation progress across every checklist this account owns —
  /// checked items / total items, 0 when there are none yet.
  Future<double> getPreparationProgress() async {
    final accountId = _accountId;
    if (accountId == null) return 0;
    final items = await plannerService.getAllItems(accountId);
    if (items.isEmpty) return 0;
    final checked = items.where((i) => i.isChecked).length;
    return checked / items.length;
  }

  // ---- Inventory ----

  Future<List<InventoryItem>> getInventory() async {
    final accountId = _accountId;
    if (accountId == null) return [];
    return plannerService.getInventory(accountId);
  }

  Future<bool> createInventoryItem(InventoryItem item) {
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.createInventoryItem(
      InventoryItem(
        accountId: accountId,
        name: item.name,
        category: item.category,
        quantity: item.quantity,
        unit: item.unit,
        expiryDate: item.expiryDate,
      ),
    );
  }

  Future<bool> updateInventoryItem(String id, Map<String, dynamic> updates) {
    return plannerService.updateInventoryItem(id, updates);
  }

  Future<bool> deleteInventoryItem(String id) => plannerService.deleteInventoryItem(id);

  // ---- Emergency contacts ----

  Future<List<EmergencyContact>> getContacts() async {
    final accountId = _accountId;
    if (accountId == null) return [];
    return plannerService.getContacts(accountId);
  }

  Future<bool> createContact(EmergencyContact contact) {
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.createContact(
      EmergencyContact(
        accountId: accountId,
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        relationship: contact.relationship,
        notes: contact.notes,
      ),
    );
  }

  Future<bool> updateContact(String id, Map<String, dynamic> updates) {
    return plannerService.updateContact(id, updates);
  }

  Future<bool> deleteContact(String id) => plannerService.deleteContact(id);
}
