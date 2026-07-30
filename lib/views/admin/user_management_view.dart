import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../controllers/user_management_controller.dart';
import '../../services/user_management_service.dart';
import '../../utils/responsive.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  static const _roles = ['user', 'helper', 'admin'];

  final _controller = UserManagementController(UserManagementService());
  late Future<List<Account>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // NOTE: must be a block body `{ ... }`, not an arrow `=> expr`. An arrow
  // body would make the assignment's *value* (a Future) the return value of
  // the closure, and setState() only accepts callbacks that return void —
  // that mismatch is what throws "setState() callback argument returned a
  // Future" at runtime.
  void _refresh() {
    setState(() {
      _usersFuture = _controller.listUsers();
    });
  }

  Future<void> _changeRole(Account account, String role) async {
    if (role == account.role) return;
    final ok = await _controller.changeRole(account.id, role);
    if (!mounted) return;
    if (ok) {
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update role')),
      );
    }
  }

  Future<void> _toggleActive(Account account) async {
    final ok = await _controller.setActive(account.id, !account.isActive);
    if (!mounted) return;
    if (ok) {
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update account status')),
      );
    }
  }

  Future<void> _changeStatus(Account account, String status) async {
    final ok = await _controller.changeStatus(account.id, status);
    if (!mounted) return;
    if (ok) {
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  Future<void> _confirmDelete(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove user?'),
        content: Text('This will permanently delete ${account.name} (${account.email}).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await _controller.removeUser(account.id);
    if (!mounted) return;
    if (ok) {
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete user')),
      );
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'helper':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<List<Account>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data ?? [];
              if (users.isEmpty) {
                return const Center(child: Text('No users found.'));
              }

              return ListView.builder(
                padding: EdgeInsets.all(
                  context.responsive(mobile: 16, tablet: 24, desktop: 32),
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final account = users[index];
                  final roleColor = _roleColor(account.role);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: roleColor.withValues(alpha: 0.15),
                              child: Text(
                                account.name.isNotEmpty
                                    ? account.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    account.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    account.email,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () => _confirmDelete(account),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                // Guard against role values that don't match
                                // any of _roles (blank/legacy data) — that
                                // mismatch is what throws a red-screen
                                // assertion from DropdownButtonFormField.
                                initialValue:
                                    _roles.contains(account.role) ? account.role : null,
                                hint: Text(account.role),
                                isDense: true,
                                decoration: InputDecoration(
                                  labelText: 'Role',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                items: _roles
                                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) _changeRole(account, value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                Switch(
                                  value: account.isActive,
                                  activeThumbColor: Colors.green,
                                  onChanged: (_) => _toggleActive(account),
                                ),
                                Text(
                                  account.isActive ? 'Active' : 'Disabled',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: account.isActive ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (account.status == 'pending')
                          Row(
                            children: [
                              const Text(
                                'Pending approval',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _changeStatus(account, 'rejected'),
                                child: const Text('Reject', style: TextStyle(color: Colors.red)),
                              ),
                              ElevatedButton(
                                onPressed: () => _changeStatus(account, 'active'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text(
                                  'Approve',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Status: ${account.status}',
                            style: TextStyle(
                              fontSize: 12,
                              color: account.status == 'rejected'
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
