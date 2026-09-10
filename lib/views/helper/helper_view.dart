import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../controllers/helper_assignment_controller.dart';
import '../../models/helper_district_assignment.dart';
import '../../services/asset_loss_report_service.dart';
import '../../services/helper_assignment_service.dart';
import '../../services/realtime_alert_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import '../shared/user_profile.dart';
import 'asset_loss_helper_verify_view.dart';
import 'shelter_occupancy_view.dart';

class HelperHome extends StatefulWidget {
  const HelperHome({super.key});

  @override
  State<HelperHome> createState() => _HelperHomeState();
}

class _HelperHomeState extends State<HelperHome> {
  int currentIndex = 0;

  final List<String> titles = ["Dashboard", "Shelters", "Profile"];

  @override
  void initState() {
    super.initState();
    _startWatches();
  }

  Future<void> _startWatches() async {
    final accountId = Supabase.instance.client.auth.currentUser?.id;
    if (accountId == null) return;
    // Task 12 "aid assignment updates" — notifies this helper of new
    // district assignments, and of new asset loss reports in areas
    // they're already assigned to.
    RealtimeAlertService.instance.watchHelperAssignments(accountId);
    final assignments = await HelperAssignmentController(HelperAssignmentService()).getMyAssignments();
    RealtimeAlertService.instance.watchAssignedDistrictReports(accountId, assignments: assignments);
  }

  @override
  void dispose() {
    RealtimeAlertService.instance.stopAssetLossReportWatch();
    RealtimeAlertService.instance.stopHelperAssignmentWatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = const [
      _HelperDashboardTab(),
      ShelterOccupancyView(),
      ProfilePage(),
    ];

    final bool useRail = !context.isMobile;

    return PopScope(
      // Only let back actually leave this screen when already on the
      // Dashboard tab — otherwise it pops the whole HelperHome route
      // instead of just returning to Dashboard like a bottom-nav app should.
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => currentIndex = 0);
      },
      child: Scaffold(
      appBar: AppBar(title: Text(titles[currentIndex])),
      // Both orientations keep an identical body element tree —
      // LayoutBuilder > Row > Expanded(keyed) > IndexedStack — and only
      // add/remove the leading NavigationRail. Without this, crossing the
      // `useRail` width breakpoint on rotation swapped the whole body subtree,
      // remounting each tab body and wiping its filter/search/scroll state.
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              if (useRail) ...[
                // NavigationRail isn't internally scrollable, so on a short
                // (e.g. landscape) screen it can overflow vertically. Let it
                // scroll while still stretching to fill the available
                // height so the VerticalDivider spans the full body.
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        onDestinationSelected: (index) =>
                            setState(() => currentIndex = index),
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            label: Text("Dashboard"),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.night_shelter_outlined),
                            label: Text("Shelters"),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.person),
                            label: Text("Profile"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                key: const ValueKey('helperTabBody'),
                child: IndexedStack(index: currentIndex, children: pages),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: useRail
          ? null
          : BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),
          BottomNavigationBarItem(icon: Icon(Icons.night_shelter_outlined), label: "Shelters"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      ),
    );
  }
}

/// Helper's district-scoped verification queue (Task/asset report §28):
/// "My Assigned Areas" + potential asset losses awaiting verification in
/// those areas. RLS already restricts what comes back to the helper's
/// active district assignments (0025_asset_loss_helper_district_scoping.sql)
/// — this view doesn't need to filter on top of that.
class _HelperDashboardTab extends StatefulWidget {
  const _HelperDashboardTab();

  @override
  State<_HelperDashboardTab> createState() => _HelperDashboardTabState();
}

class _HelperDashboardTabState extends State<_HelperDashboardTab> {
  final _assignmentController = HelperAssignmentController(HelperAssignmentService());
  final _reportController = AssetLossReportController(AssetLossReportService());

  bool _isLoading = true;
  List<HelperDistrictAssignment> _assignments = [];
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final assignments = await _assignmentController.getMyAssignments();
    final reports = await _reportController.getMyDistrictReports();
    if (!mounted) return;
    setState(() {
      _assignments = assignments;
      _reports = reports;
      _isLoading = false;
    });
  }

  Future<void> _refresh() => _load();

  Future<void> _openReport(Map<String, dynamic> data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssetLossHelperVerifyView(
          data: data,
          controller: _reportController,
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_assignments.isEmpty) {
      return const EmptyState(
        icon: Icons.map_outlined,
        iconColor: Colors.blue,
        title: 'No areas assigned yet',
        subtitle: 'An admin needs to assign you to a state/district before you can verify reports.',
      );
    }

    int byNewest(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (b['created_at'] as String).compareTo(a['created_at'] as String);

    // A helper can only act on reports that are still pending AND not yet
    // verified by anyone (matches migration 0036's RLS). Everything else is
    // view-only.
    bool awaitingVerification(Map<String, dynamic> r) =>
        r['status'] == 'pending_review' && r['verification_result'] == null;

    final toVerify = _reports.where(awaitingVerification).toList()..sort(byNewest);
    final reviewed = _reports.where((r) => !awaitingVerification(r)).toList()
      ..sort(byNewest);

    final pendingByDistrict = <String, List<Map<String, dynamic>>>{};
    for (final r in toVerify) {
      final property = r['property'] as Map<String, dynamic>?;
      final key = '${property?['district'] ?? 'Unknown'}, ${property?['state'] ?? ''}';
      pendingByDistrict.putIfAbsent(key, () => []).add(r);
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.all(context.responsive(mobile: 16, tablet: 24, desktop: 24)),
            children: [
              const Text('My Assigned Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _assignments
                    .map((a) => Chip(
                          avatar: const Icon(Icons.location_on, size: 16, color: Colors.blue),
                          label: Text('${a.district}, ${a.state}'),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Potential Asset Losses Requiring Verification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              if (pendingByDistrict.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No pending reports in your areas right now.', style: TextStyle(color: Colors.grey)),
                )
              else
                ...pendingByDistrict.entries.map((entry) {
                  final totalPotential = entry.value.fold<double>(
                    0,
                    (sum, r) => sum + ((r['estimated_total_loss'] as num?)?.toDouble() ?? 0),
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.04),
                      border: Border.all(color: Colors.blue.shade100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Pending: ${entry.value.length}', style: const TextStyle(fontSize: 12)),
                            Text(
                              '${formatRinggit(totalPotential)} potential loss',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 24),
              const Text(
                'Awaiting Your Verification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              if (toVerify.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nothing to verify right now.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...toVerify.map((data) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReportCard(
                        data: data,
                        onTap: () => _openReport(data),
                      ),
                    )),
              if (reviewed.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Reviewed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Already verified or decided by an admin — view only.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ...reviewed.map((data) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Opacity(
                        opacity: 0.7,
                        child: _ReportCard(
                          data: data,
                          onTap: () => _openReport(data),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending_review';
    final property = data['property'] as Map<String, dynamic>?;
    final estimatedTotal = (data['estimated_total_loss'] as num?)?.toDouble() ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${data['asset_category']} — ${data['asset_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 6),
            if (property != null)
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${property['address'] ?? ''} (${property['district']}, ${property['state']})',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              'Condition: ${assetConditionLabels[data['condition']] ?? data['condition']}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Potential loss: ${formatRinggit(estimatedTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blue, fontSize: 13),
            ),
            if (data['verification_result'] != null &&
                status == 'pending_review') ...[
              const SizedBox(height: 4),
              Text(
                'Verified — awaiting admin approval',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
