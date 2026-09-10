import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';
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

  Future<bool> updateRole(String id, String role, {bool activate = false}) async {
    try {
      final rows = await supabase
          .from(_table)
          .update({'role': role, if (activate) 'status': 'active'})
          .eq('id', id)
          .select();
      return _changed(rows, 'updateRole', id);
    } catch (e) {
      debugPrint('UserManagementService.updateRole error: $e');
      return false;
    }
  }

  Future<bool> setActive(String id, bool isActive) async {
    try {
      final rows = await supabase
          .from(_table)
          .update({'is_active': isActive})
          .eq('id', id)
          .select();
      return _changed(rows, 'setActive', id);
    } catch (e) {
      debugPrint('UserManagementService.setActive error: $e');
      return false;
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    try {
      final rows = await supabase
          .from(_table)
          .update({'status': status})
          .eq('id', id)
          .select();
      return _changed(rows, 'updateStatus', id);
    } catch (e) {
      debugPrint('UserManagementService.updateStatus error: $e');
      return false;
    }
  }

  bool _changed(Object? rows, String op, String id) {
    final list = rows as List;
    if (list.isEmpty) {
      debugPrint(
        'UserManagementService.$op: 0 rows for $id — the admin update policy '
        'on `account` is missing (apply migration 0016) or you are not an admin.',
      );
      return false;
    }
    return true;
  }
}
