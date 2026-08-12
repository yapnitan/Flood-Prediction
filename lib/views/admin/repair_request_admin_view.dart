import 'package:flutter/material.dart';
import '../../controllers/repair_request_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/account.dart';
import '../../services/repair_request_service.dart';
import '../../services/user_management_service.dart';
import '../../utils/responsive.dart';
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

  @override
  void initState() {
    super.initState();
    _requestsFuture = _requestController.getAdminOverview();
    _loadHelpers();
  }

  Future<void> _loadHelpers() async {
    final users = await _userController.listUsers();
    if (!mounted) return;
    setState(() {
      _helpers = users
          .where((u) => u.role == 'helper' && u.isActive && u.status == 'active')
          .toList();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _requestsFuture = _requestController.getAdminOverview());
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
    await _requestController.updateRequest(requestId, shelterName: shelterName);
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
                        const priorityRank = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
                        requests.sort((a, b) {
                          final pa = priorityRank[a['priority']] ?? 4;
                          final pb = priorityRank[b['priority']] ?? 4;
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
}

class _AdminRequestSummaryCard extends StatelessWidget {
  const _AdminRequestSummaryCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final priority = data['priority'] as String? ?? 'medium';
    final account = data['account'] as Map<String, dynamic>?;
    final photoCount = (data['photo_paths'] as List?)?.length ?? 0;

    final priorityColor = switch (priority) {
      'urgent' => Colors.red,
      'high' => Colors.orange,
      'low' => Colors.grey,
      _ => Colors.blue,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
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
                    data['assistance_type'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            if (account != null) ...[
              const SizedBox(height: 4),
              Text('From: ${account['name'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag, size: 14, color: priorityColor),
                const SizedBox(width: 4),
                Text(priority, style: TextStyle(color: priorityColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
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
          ],
        ),
      ),
    );
  }
}