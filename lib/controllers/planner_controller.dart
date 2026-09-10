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

  Future<bool> renameChecklist(String id, String title) {
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.renameChecklist(id, title, accountId);
  }

  Future<bool> deleteChecklist(String id) {
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.deleteChecklist(id, accountId);
  }


  Future<List<ChecklistItem>> getItems(String checklistId) => plannerService.getItems(checklistId);

  Future<bool> addItem(String checklistId, String label) {
    return plannerService.addItem(ChecklistItem(checklistId: checklistId, label: label));
  }

  Future<bool> setItemChecked(String id, bool checked, String checklistId) {
    return plannerService.setItemChecked(id, checked, checklistId);
  }

  Future<bool> deleteItem(String id, String checklistId) => plannerService.deleteItem(id, checklistId);

  Future<double> getPreparationProgress() async {
    final accountId = _accountId;
    if (accountId == null) return 0;
    final items = await plannerService.getAllItems(accountId);
    if (items.isEmpty) return 0;
    final checked = items.where((i) => i.isChecked).length;
    return checked / items.length;
  }

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
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.updateInventoryItem(id, updates, accountId);
  }

  Future<bool> deleteInventoryItem(String id) {
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.deleteInventoryItem(id, accountId);
  }


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
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.updateContact(id, updates, accountId);
  }

  Future<bool> deleteContact(String id) {
    final accountId = _accountId;
    if (accountId == null) return Future.value(false);
    return plannerService.deleteContact(id, accountId);
  }
}
