import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../controllers/user_management_controller.dart';
import '../../services/user_management_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/adaptive_search_filter_header.dart';
import '../../widgets/empty_state.dart';

/// Circle avatar for a user row — shows their profile picture (the
/// `avatars` bucket is public, so a plain network image) and falls back to
/// the first letter of their name while it loads or if it fails / isn't set.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.url, required this.color});

  final String name;
  final String? url;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final letter = Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: letter,
      );
    }
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: ClipOval(
        child: Image.network(
          url!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(child: letter),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : Center(child: letter),
        ),
      ),
    );
  }
}

/// Icon + short caption for an account's approval status. Kept to its
/// intrinsic width so it can sit next to (or wrap away from) the action
/// buttons in [_UserManagementViewState._buildApprovalControl].
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

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
  static const _statusFilters = ['All', 'Pending', 'Active', 'Rejected'];
  static const _roleFilters = ['All', 'User', 'Helper', 'Admin'];

  final _controller = UserManagementController(UserManagementService());
  final _searchController = TextEditingController();
  late Future<List<Account>> _usersFuture;

  /// The signed-in admin — their own account's role/status/enabled controls
  /// are locked so they can't accidentally lock themselves out.
  final String? _myId = Supabase.instance.client.auth.currentUser?.id;

  String _searchQuery = '';
  String _statusFilter = 'All';
  String _roleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Account> _applyFilters(List<Account> accounts) {
    return accounts.where((account) {
      final matchesStatus =
          _statusFilter == 'All' ||
          account.status == _statusFilter.toLowerCase();
      if (!matchesStatus) return false;

      final matchesRole =
          _roleFilter == 'All' || account.role == _roleFilter.toLowerCase();
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _roleLabel(String role) =>
      role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}';

  bool _isSelf(Account account) => account.id == _myId;

  Future<void> _changeRole(Account account, String role) async {
    if (role == account.role || _isSelf(account)) return;

    final confirmed = await _confirmRoleChange(account, role);
    if (confirmed != true) return;

    // A pending/rejected account an admin is deliberately assigning a role
    // to is being approved by that action — clear it so it isn't locked out
    // (e.g. a still-pending helper demoted to a plain user).
    final activate = account.status != 'active';
    final ok = await _controller.changeRole(account.id, role, activate: activate);
    if (!mounted) return;
    if (ok) {
      _refresh();
      widget.onUsersChanged?.call();
    } else {
      _snack('Failed to update role');
    }
  }

  Future<bool?> _confirmRoleChange(Account account, String role) {
    final who = account.name.isNotEmpty ? account.name : account.email;
    final String body;
    if (role == 'admin') {
      body = '$who will be able to manage every account and all data.';
    } else if (account.role == 'admin') {
      body = '$who will lose admin access.';
    } else {
      body = '$who will become a ${_roleLabel(role)} on their next sign-in.';
    }
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change role to ${_roleLabel(role)}?'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change role'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Account account) async {
    if (_isSelf(account)) return;
    final ok = await _controller.setActive(account.id, !account.isActive);
    if (!mounted) return;
    if (ok) {
      _refresh();
    } else {
      _snack('Failed to update account status');
    }
  }

  Future<void> _setStatus(Account account, String status) async {
    final ok = await _controller.changeStatus(account.id, status);
    if (!mounted) return;
    if (ok) {
      _refresh();
      widget.onUsersChanged?.call();
    } else {
      _snack('Failed to update approval status');
    }
  }

  Future<void> _approve(Account account) => _setStatus(account, 'active');

  Future<void> _reject(Account account) async {
    final who = account.name.isNotEmpty ? account.name : account.email;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this sign-up?'),
        content: Text("$who won't be able to log in. You can reconsider later."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _setStatus(account, 'rejected');
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

  Widget _buildUserCard(Account account) {
    final roleColor = _roleColor(account.role);
    final isSelf = _isSelf(account);

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
              _Avatar(
                name: account.name,
                url: account.avatarUrl,
                color: roleColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name.isEmpty ? '(no name)' : account.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
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
                  // Guard against role values outside _roles (blank/legacy
                  // data) — that mismatch red-screens DropdownButtonFormField.
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
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(_roleLabel(r)),
                          ))
                      .toList(),
                  onChanged: isSelf
                      ? null
                      : (value) {
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
                    onChanged: isSelf ? null : (_) => _toggleActive(account),
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
          _buildApprovalControl(account),
        ],
      ),
    );
  }

  /// Approval workflow — shown only for helper/admin accounts. A plain
  /// `user` never needs approval (migration 0016 makes them `active` on
  /// sign-up), and there is deliberately no way back to `pending`.
  Widget _buildApprovalControl(Account account) {
    if (account.role == 'user') return const SizedBox.shrink();

    final isSelf = _isSelf(account);
    final Widget content;
    switch (account.status) {
      case 'pending':
        // Wrap (not Row+Spacer) so the two action buttons drop below the
        // status label on a narrow card instead of overflowing it.
        content = Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const _StatusLabel(
              icon: Icons.hourglass_top,
              text: 'Awaiting review',
              color: Colors.orange,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: isSelf ? null : () => _reject(account),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isSelf ? null : () => _approve(account),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        );
      case 'rejected':
        content = Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const _StatusLabel(
              icon: Icons.block,
              text: 'Rejected',
              color: Colors.red,
            ),
            TextButton(
              onPressed: isSelf ? null : () => _approve(account),
              child: const Text('Reconsider'),
            ),
          ],
        );
      default: // 'active'
        content = const _StatusLabel(
          icon: Icons.verified_user_outlined,
          text: 'Approved',
          color: Colors.green,
        );
    }
    return Padding(padding: const EdgeInsets.only(top: 10), child: content);
  }

  /// One labelled, wrapping row of filter chips for the portrait inline
  /// header — "Status" / "Role" each get their own line so nothing is
  /// hidden off-screen behind a horizontal scroll.
  Widget _filterRow({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 10),
            child: SizedBox(
              width: 44,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  ChoiceChip(
                    label: Text(option),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
              maxWidth: context.responsive(
                mobile: 700,
                tablet: 800,
                desktop: 900,
              ),
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
                  child: AdaptiveSearchFilterHeader(
                    searchField: TextField(
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
                    portraitFilters: [
                      _filterRow(
                        label: 'Status',
                        options: _statusFilters,
                        selected: _statusFilter,
                        onSelected: (value) =>
                            setState(() => _statusFilter = value),
                      ),
                      _filterRow(
                        label: 'Role',
                        options: _roleFilters,
                        selected: _roleFilter,
                        onSelected: (value) =>
                            setState(() => _roleFilter = value),
                      ),
                    ],
                    sheetTitle: 'Filter users',
                    activeFilterCount:
                        (_statusFilter == 'All' ? 0 : 1) +
                        (_roleFilter == 'All' ? 0 : 1),
                    sheetBuilder: (context, setSheetState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final status in _statusFilters)
                              ChoiceChip(
                                label: Text(status),
                                selected: _statusFilter == status,
                                onSelected: (_) {
                                  setState(() => _statusFilter = status);
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Role',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final role in _roleFilters)
                              ChoiceChip(
                                label: Text(role),
                                selected: _roleFilter == role,
                                onSelected: (_) {
                                  setState(() => _roleFilter = role);
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
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
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                            context.responsive(
                              mobile: 16,
                              tablet: 24,
                              desktop: 32,
                            ),
                          ),
                          itemCount: users.length,
                          itemBuilder: (context, index) =>
                              _buildUserCard(users[index]),
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
