import 'package:flutter/material.dart';
import '../../controllers/repair_request_controller.dart';
import '../../models/repair_request.dart';
import '../../services/repair_request_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/status_badge.dart';
import 'repair_request_detail_view.dart';

class MyRepairRequestsView extends StatefulWidget {
  const MyRepairRequestsView({super.key});

  @override
  State<MyRepairRequestsView> createState() => _MyRepairRequestsViewState();
}

class _MyRepairRequestsViewState extends State<MyRepairRequestsView> {
  final _controller = RepairRequestController(RepairRequestService());
  late Future<List<RepairRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = _controller.getMyRequests();
  }

  Future<void> _refresh() async {
    // Block body, not `=> expr` — an arrow body would make the assignment's
    // *value* (a Future) the closure's return value, and setState() only
    // accepts callbacks returning void.
    setState(() {
      _requestsFuture = _controller.getMyRequests();
    });
    await _requestsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('My Repair Requests'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
            ),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<RepairRequest>>(
                future: _requestsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildMessage(
                      icon: Icons.error_outline,
                      text: 'Could not load your requests. Pull down to try again.',
                    );
                  }

                  final requests = snapshot.data ?? [];
                  if (requests.isEmpty) {
                    return _buildMessage(
                      icon: Icons.inbox_outlined,
                      text: 'You haven\'t submitted any repair requests yet.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _RequestCard(
                      request: requests[index],
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RepairRequestDetailView(
                              requestId: requests[index].id!,
                            ),
                          ),
                        );
                        _refresh();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({required IconData icon, required String text}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final RepairRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mode = request.fulfillmentMode;
    final showsFacilityStatus = mode == FulfillmentMode.facility &&
        (request.status == 'approved' || request.status == 'assigned' || request.status == 'in_progress');

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
                    request.assistanceType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.locationName,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (showsFacilityStatus) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    request.facilityId != null ? Icons.home_work_outlined : Icons.hourglass_empty,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    request.facilityId != null ? 'Facility assigned — see details' : 'Awaiting facility assignment',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ],
            if (request.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatDate(request.createdAt!),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}