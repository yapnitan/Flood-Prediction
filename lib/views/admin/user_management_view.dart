import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../controllers/user_management_controller.dart';
import '../../services/user_management_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key, this.onUsersChanged});

  /// Called after a role/status/active change succeeds, so a host screen
  /// (e.g. the admin's pending-approval badge on the Users tab) can refresh
  /// without waiting for a tab switch.
  final VoidCallback? onUsersChanged;

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  static const _roles = ['user', 'helper', 'admin'];
  static const _statuses = ['pending', 'active', 'rejected'];
  static const _statusFilters = ['All', 'Pending', 'Active', 'Rejected'];
  static const _roleFilters = ['All', 'User', 'Helper', 'Admin'];

  final _controller = UserManagementController(UserManagementService());
  final _searchController = TextEditingController();
  late Future<List<Account>> _usersFuture;

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _roleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Account> _applyFilters(List<Account> accounts) {
    return accounts.where((account) {
      final matchesStatus = _statusFilter == 'All' ||
          account.status == _statusFilter.toLowerCase();
      if (!matchesStatus) return false;

      final matchesRole = _roleFilter == 'All' ||
          account.role == _roleFilter.toLowerCase();
      if (!matchesRole) return false;

      if (_searchQuery.isEmpty) return true;
      return account.name.toLowerCase().contains(_searchQuery) ||
          account.email.toLowerCase().contains(_searchQuery);
    }).toList();
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
      widget.onUsersChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
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
        // Cap the content width and center it — without this, on a wide
        // landscape screen (the NavigationRail eats the left edge but what's
        // left is still very wide) the search bar and filter chips stretch
        // edge-to-edge and look oversized, same as every other admin page.
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.responsive(mobile: 16, tablet: 24, desktop: 32),
                    16,
                    context.responsive(mobile: 16, tablet: 24, desktop: 32),
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or email',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _searchController.clear,
                                ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // A single horizontally-scrolling row (rather than two
                      // stacked Wrap rows) keeps the header compact — on a
                      // landscape phone the body height is short, and two
                      // fixed rows of chips ate too much of it, squeezing
                      // the scrollable list below into a tiny sliver.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final status in _statusFilters)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(status),
                                  selected: _statusFilter == status,
                                  onSelected: (_) =>
                                      setState(() => _statusFilter = status),
                                ),
                              ),
                            Container(
                              width: 1,
                              height: 24,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(width: 8),
                            for (final role in _roleFilters)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(role),
                                  selected: _roleFilter == role,
                                  onSelected: (_) =>
                                      setState(() => _roleFilter = role),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: FutureBuilder<List<Account>>(
                      future: _usersFuture,
                      builder: (context, snapshot) {
                        // Only show the full-screen spinner on the very first
                        // load. FutureBuilder keeps the previous snapshot.data
                        // around while a new future is in flight, so reusing it
                        // here (instead of blanking the list on every refresh)
                        // keeps the same ListView mounted and its scroll
                        // position intact after actions like toggling a user's
                        // active state.
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final users = _applyFilters(snapshot.data ?? []);
                        if (users.isEmpty) {
                          return const EmptyState(
                            icon: Icons.people_outline,
                            title: 'No users found.',
                          );
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
                                  Row(
                                    children: [
                                      if (account.status == 'pending')
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(Icons.hourglass_top, size: 16, color: Colors.orange),
                                        ),
                                      Expanded(
                                        // Always editable, not just while pending —
                                        // lets admin approve/reject or reconsider a
                                        // past decision at any time, rather than
                                        // rejected being a dead end.
                                        child: DropdownButtonFormField<String>(
                                          initialValue:
                                              _statuses.contains(account.status) ? account.status : null,
                                          hint: Text(account.status),
                                          isDense: true,
                                          decoration: InputDecoration(
                                            labelText: 'Status',
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          items: _statuses
                                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                              .toList(),
                                          onChanged: (value) {
                                            if (value != null) _changeStatus(account, value);
                                          },
                                        ),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
