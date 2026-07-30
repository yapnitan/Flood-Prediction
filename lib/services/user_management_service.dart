import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';

/// Admin-only operations over the `account` table: listing every user,
/// changing roles, enabling/disabling accounts, and removing accounts.
///
/// This assumes Supabase row-level security restricts these write
/// operations to admins server-side — this service does not itself
/// check the caller's role.
class UserManagementService {
  final supabase = Supabase.instance.client;
  static const String _table = 'account';

  Future<List<Account>> getAllAccounts() async {
    try {
      final rows = await supabase.from(_table).select().order('name');
      return (rows as List)
          .map((r) => Account.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('UserManagementService.getAllAccounts error: $e');
      return [];
    }
  }

  Future<bool> updateRole(String id, String role) async {
    try {
      await supabase.from(_table).update({'role': role}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('UserManagementService.updateRole error: $e');
      return false;
    }
  }

  Future<bool> setActive(String id, bool isActive) async {
    try {
      await supabase.from(_table).update({'is_active': isActive}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('UserManagementService.setActive error: $e');
      return false;
    }
  }

  Future<bool> deleteAccount(String id) async {
    try {
      await supabase.from(_table).delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('UserManagementService.deleteAccount error: $e');
      return false;
    }
  }
}
