import 'package:flutter/material.dart';

import '../../controllers/asset_loss_report_controller.dart';
import '../../controllers/helper_assignment_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/account.dart';
import '../../models/helper_district_assignment.dart';
import '../../services/asset_loss_report_service.dart';
import '../../services/helper_assignment_service.dart';
import '../../services/user_management_service.dart';
import '../../utils/malaysia_geocoding.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';

/// Admin's Helper Assignment page (Task/asset report §32-§34): assigns
/// approved helpers to a state/district so they can verify Potential Asset
/// Loss reports there. A district-coverage grid (§33) is intentionally out
/// of scope for now — it would require enumerating every Malaysian
/// district up front; the assignment list below already surfaces which
/// districts currently have an active helper.
class HelperAssignmentAdminView extends StatefulWidget {
  const HelperAssignmentAdminView({super.key});

  @override
  State<HelperAssignmentAdminView> createState() => _HelperAssignmentAdminViewState();
}

class _HelperAssignmentAdminViewState extends State<HelperAssignmentAdminView> {
  final _assignmentController = HelperAssignmentController(HelperAssignmentService());
  final _userManagementController = UserManagementController(UserManagementService());
  final _assetLossController = AssetLossReportController(AssetLossReportService());

  bool _isLoading = true;
  List<Map<String, dynamic>> _assignments = [];
  List<Account> _helpers = [];
  Map<String, int> _pendingByDistrict = {};
  Map<String, int> _completedByDistrict = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final assignments = await _assignmentController.getAllWithHelperInfo();
    final accounts = await _userManagementController.listUsers();
    final reports = await _assetLossController.getAdminOverview();
    if (!mounted) return;

    final pending = <String, int>{};
    final completed = <String, int>{};
    for (final r in reports) {
      final property = r['property'] as Map<String, dynamic>?;
      if (property == null) continue;
      final key = '${property['state']}|${property['district']}';
      if (r['status'] == 'pending_review') {
        pending[key] = (pending[key] ?? 0) + 1;
      } else if (r['status'] == 'verified' || r['status'] == 'rejected') {
        completed[key] = (completed[key] ?? 0) + 1;
      }
    }

    setState(() {
      _assignments = assignments;
      _helpers = accounts.where((a) => a.role == 'helper' && a.status == 'active').toList();
      _pendingByDistrict = pending;
      _completedByDistrict = completed;
      _isLoading = false;
    });
  }

  Future<void> _openAssignDialog({Map<String, dynamic>? existing}) async {
    String? helperId = existing?['helper_id'] as String?;
    String state = existing?['state'] as String? ?? MalaysiaGeocoder.states.first;
    final districtController = TextEditingController(text: existing?['district'] as String? ?? '');
    final districtFocusNode = FocusNode();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(existing == null ? 'Assign Helper' : 'Reassign District'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _helpers.any((h) => h.id == helperId) ? helperId : null,
                decoration: const InputDecoration(labelText: 'Helper'),
                items: _helpers.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))).toList(),
                onChanged: (value) => setDialogState(() => helperId = value),
                hint: Text(_helpers.isEmpty ? 'No active helpers available' : 'Select a helper'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: state,
                decoration: const InputDecoration(labelText: 'State'),
                items: MalaysiaGeocoder.states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) => setDialogState(() {
                  if (value == null || value == state) return;
                  state = value;
                  if (!MalaysiaGeocoder.districtsFor(state).contains(districtController.text.trim())) {
                    districtController.clear();
                  }
                }),
              ),
              const SizedBox(height: 12),
              RawAutocomplete<String>(
                key: ValueKey(state),
                textEditingController: districtController,
                focusNode: districtFocusNode,
                optionsBuilder: (value) {
                  final districts = MalaysiaGeocoder.districtsFor(state);
                  final query = value.text.trim().toLowerCase();
                  if (query.isEmpty) return districts;
                  return districts.where((d) => d.toLowerCase().contains(query));
                },
                onSelected: (value) => districtController.text = value,
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: options.map((district) {
                          return ListTile(
                            dense: true,
                            title: Text(district),
                            onTap: () => onSelected(district),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'District', hintText: 'e.g. Petaling'),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (helperId == null || districtController.text.trim().isEmpty) return;
                final error = await _assignmentController.assign(HelperDistrictAssignment(
                  helperId: helperId!,
                  state: state,
                  district: districtController.text.trim(),
                ));
                if (!context.mounted) return;
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deactivate(String id) async {
    final error = await _assignmentController.deactivate(id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _load();
  }

  Future<void> _reactivate(String id) async {
    final error = await _assignmentController.reactivate(id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Helper Assignments'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAssignDialog(),
        tooltip: 'Assign helper',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _assignments.isEmpty
                        ? const EmptyState(
                            icon: Icons.map_outlined,
                            title: 'No helper assignments yet',
                            subtitle: 'Tap + to assign an approved helper to a state/district.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                            itemCount: _assignments.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final a = _assignments[index];
                              final account = a['account'] as Map<String, dynamic>?;
                              final isActive = a['status'] == 'active';
                              final key = '${a['state']}|${a['district']}';
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isActive ? null : Colors.grey.withValues(alpha: 0.05),
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
                                            account?['name'] as String? ?? 'Unknown helper',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isActive ? 'ACTIVE' : 'INACTIVE',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${a['district']}, ${a['state']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text('Pending: ${_pendingByDistrict[key] ?? 0}', style: const TextStyle(fontSize: 12)),
                                        const SizedBox(width: 16),
                                        Text('Completed: ${_completedByDistrict[key] ?? 0}', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        if (isActive) ...[
                                          TextButton(
                                            onPressed: () => _openAssignDialog(existing: a),
                                            child: const Text('Reassign'),
                                          ),
                                          TextButton(
                                            onPressed: () => _deactivate(a['id'] as String),
                                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            child: const Text('Deactivate'),
                                          ),
                                        ] else
                                          TextButton(
                                            onPressed: () => _reactivate(a['id'] as String),
                                            child: const Text('Reactivate'),
                                          ),
                                      ],
                                    ),
                                  ],
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
}
