import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';

/// Admin-only operations over the `account` table: listing every user,
/// changing roles, enabling/disabling accounts, and approving/rejecting
/// (or reconsidering) sign-ups. Deliberately no delete — disabling
/// (`setActive`) is the moderation tool; deleting would orphan any
/// repair requests/flood reports the account left behind and can't be
/// undone.
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

  /// [activate] also clears a `pending`/`rejected` status to `active` — an
  /// admin deliberately assigning a role is an act of approval, and leaving
  /// a demoted-to-`user` account stuck at `pending` would lock it out.
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

  /// Approval workflow — separate from [setActive]. Pass 'active' to
  /// approve a pending sign-up, or 'rejected' to reject it.
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

  /// `.update()` succeeds silently even when RLS matched 0 rows — `.select()`
  /// lets us tell a real change from a no-op (missing admin policy / trigger).
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
