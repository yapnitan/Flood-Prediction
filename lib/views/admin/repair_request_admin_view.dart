import 'package:flutter/material.dart';
import '../../controllers/repair_request_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/account.dart';
import '../../models/repair_request.dart';
import '../../services/repair_request_service.dart';
import '../../services/user_management_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/status_badge.dart';
import 'repair_request_admin_detail_view.dart';

class RepairRequestAdminView extends StatefulWidget {
  const RepairRequestAdminView({super.key, this.onRequestsChanged});

  final VoidCallback? onRequestsChanged;

  @override
  State<RepairRequestAdminView> createState() => _RepairRequestAdminViewState();
}

class _RepairRequestAdminViewState extends State<RepairRequestAdminView> {
  final _requestController = RepairRequestController(RepairRequestService());
  final _userController = UserManagementController(UserManagementService());

  late Future<List<Map<String, dynamic>>> _requestsFuture;
  List<Account> _helpers = [];
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

  final List<String> _statusOptions = [
    'all',
    'pending',
    'approved',
    'assigned',
    'in_progress',
    'completed',
    'rejected',
    'cancelled',
  ];

  final List<String> _priorityOptions = ['all', 'urgent', 'high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _requestsFuture = _requestController.getAdminOverview();
    _reloadHelpers();
  }

  /// Fetches + filters active helpers, updates this tab's own list for the
  /// dropdown filter bar, *and* returns the fresh list so
  /// [RepairRequestAdminDetailView] (which keeps its own copy) can refresh
  /// after its "+ Add Helper" shortcut returns from User Management.
  Future<List<Account>> _reloadHelpers() async {
    final users = await _userController.listUsers();
    final helpers = users
        .where((u) => u.role == 'helper' && u.isActive && u.status == 'active')
        .toList();
    if (mounted) setState(() => _helpers = helpers);
    return helpers;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    // Must be a block body `{ ... }`, not an arrow `=> expr` — an arrow body
    // would make the assignment's *value* (a Future) the return value of the
    // closure, and setState() only accepts callbacks that return void. That
    // mismatch is what threw "setState() callback argument returned a
    // Future" every time this ran (see the same note in
    // user_management_view.dart's _refresh).
    setState(() {
      _requestsFuture = _requestController.getAdminOverview();
    });
    await _requestsFuture;
  }

  Future<void> _approve(String requestId) async {
    await _requestController.approveRequest(requestId);
    await _refresh();
    widget.onRequestsChanged?.call();
  }

  Future<void> _reject(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this request?'),
        content: const Text('The requester will see this as rejected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _requestController.rejectRequest(requestId);
    _refresh();
    widget.onRequestsChanged?.call();
  }

  Future<void> _setPriority(String requestId, String priority) async {
    await _requestController.setPriority(requestId, priority);
    _refresh();
  }

  Future<void> _setShelter(String requestId, String shelterName) async {
    await _requestController.updateRequest(requestId, facilityId: shelterName);
    _refresh();
  }

  Future<void> _assignHelper(String requestId, String helperId) async {
    await _requestController.assignHelper(requestId, helperId);
    _refresh();
    widget.onRequestsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(mobile: 700, tablet: 900, desktop: 1100),
            ),
            child: Column(
              children: [
                _buildFilterBar(),
                _buildPriorityFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _requestsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Could not load requests.'));
                        }

                        var requests = snapshot.data ?? [];
                        if (_statusFilter != 'all') {
                          requests = requests.where((r) => r['status'] == _statusFilter).toList();
                        }
                        if (_priorityFilter != 'all') {
                          requests = requests.where((r) => r['priority'] == _priorityFilter).toList();
                        }
                        requests.sort((a, b) {
                          final pa = RepairRequest.priorityRank[a['priority']] ??
                              RepairRequest.priorityRank.length;
                          final pb = RepairRequest.priorityRank[b['priority']] ??
                              RepairRequest.priorityRank.length;
                          return pa.compareTo(pb);
                        });

                        if (requests.isEmpty) {
                          return const Center(child: Text('No requests match this filter.'));
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: requests.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _AdminRequestSummaryCard(
                            data: requests[index],
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RepairRequestAdminDetailView(
                                    data: requests[index],
                                    helpers: _helpers,
                                    controller: _requestController,
                                    reloadHelpers: _reloadHelpers,
                                  ),
                                ),
                              );
                              await _refresh();
                              widget.onRequestsChanged?.call();
                            },
                          ),
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

  Widget _buildFilterBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _statusOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statusOptions[index];
          final selected = _statusFilter == status;
          return ChoiceChip(
            label: Text(status == 'all' ? 'All' : status.replaceAll('_', ' ')),
            selected: selected,
            onSelected: (_) => setState(() => _statusFilter = status),
            selectedColor: Colors.blue.shade100,
            labelStyle: TextStyle(color: selected ? Colors.blue.shade900 : Colors.black87),
          );
        },
      ),
    );
  }

  Widget _buildPriorityFilterBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: _priorityOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final priority = _priorityOptions[index];
          final selected = _priorityFilter == priority;
          final color = priority == 'all' ? Colors.blue : PriorityBadge.colorFor(priority);
          return ChoiceChip(
            avatar: priority == 'all' ? null : Icon(Icons.flag, size: 14, color: color),
            label: Text(priority == 'all' ? 'All priorities' : priority),
            selected: selected,
            onSelected: (_) => setState(() => _priorityFilter = priority),
            selectedColor: color.withValues(alpha: 0.15),
            side: BorderSide(color: color.withValues(alpha: 0.4)),
            labelStyle: TextStyle(color: selected ? color : Colors.black87),
          );
        },
      ),
    );
  }
}

class _AdminRequestSummaryCard extends StatelessWidget {
  const _AdminRequestSummaryCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final priority = data['priority'] as String? ?? 'medium';
    final assistanceType = data['assistance_type'] as String? ?? '';
    final account = data['account'] as Map<String, dynamic>?;
    final photoCount = (data['photo_paths'] as List?)?.length ?? 0;
    final isUrgent = priority == 'urgent';
    final mode = RepairRequest.fulfillmentModeFor(assistanceType);
    final needsFacility = mode == FulfillmentMode.facility && data['facility_id'] == null;
    final isCritical = (data['details'] as Map?)?['is_critical'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUrgent ? Colors.red.withValues(alpha: 0.04) : null,
          border: Border.all(
            color: isUrgent ? Colors.red.shade200 : Colors.grey.shade300,
            width: isUrgent ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    assistanceType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            if (isCritical) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text('Critical', style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            if (account != null) ...[
              const SizedBox(height: 4),
              Text('From: ${account['name'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                PriorityBadge(priority: priority, dense: true),
                const SizedBox(width: 12),
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    data['location_name'] as String? ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (photoCount > 0) ...[
                  const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 2),
                  Text('$photoCount', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ],
            ),
            if (needsFacility && (status == 'approved' || status == 'assigned' || status == 'in_progress')) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Needs facility assignment',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}