import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/facility_controller.dart';
import '../../controllers/repair_request_controller.dart';
import '../../models/account.dart';
import '../../models/facility.dart';
import '../../models/repair_request.dart';
import '../../services/facility_service.dart';
import '../../utils/maps_launcher.dart';
import '../../widgets/add_new_dropdown_item.dart';
import '../../widgets/assistance_details_view.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';
import 'facility_form_view.dart';
import 'user_management_view.dart';

class RepairRequestAdminDetailView extends StatefulWidget {
  const RepairRequestAdminDetailView({
    super.key,
    required this.data,
    required this.helpers,
    required this.controller,
    required this.reloadHelpers,
  });

  final Map<String, dynamic> data;
  final List<Account> helpers;
  final RepairRequestController controller;

  /// Re-fetches active helpers from the parent list view — called after
  /// the "+ Add Helper" dropdown entry returns from User Management, since
  /// promoting a user to helper there won't otherwise be reflected here.
  final Future<List<Account>> Function() reloadHelpers;

  @override
  State<RepairRequestAdminDetailView> createState() => _RepairRequestAdminDetailViewState();
}

class _RepairRequestAdminDetailViewState extends State<RepairRequestAdminDetailView> {
  final _facilityController = FacilityController(FacilityService());

  late Map<String, dynamic> _data;
  late List<Account> _helpers;
  bool _isBusy = false;

  List<FacilityWithDistance> _facilitiesSorted = [];
  bool _isLoadingFacilities = false;

  static const _priorities = ['low', 'medium', 'high', 'urgent'];

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    _helpers = List<Account>.from(widget.helpers);
    _loadFacilitiesIfNeeded();
  }

  String get _id => _data['id'] as String;
  String get _status => _data['status'] as String? ?? 'pending';
  String get _assistanceType => _data['assistance_type'] as String? ?? '';
  FulfillmentMode get _fulfillmentMode => RepairRequest.fulfillmentModeFor(_assistanceType);
  String? get _requiredFacilityType {
    const map = {
      'Temporary Shelter': 'shelter',
      'Food & Water Supply': 'distribution_center',
    };
    return map[_assistanceType];
  }

  Future<void> _loadFacilitiesIfNeeded() async {
    final facilityType = _requiredFacilityType;
    if (facilityType == null) return;
    setState(() => _isLoadingFacilities = true);
    final facilities = await _facilityController.getAssignableFacilitiesSorted(
      facilityType,
      lat: (_data['latitude'] as num).toDouble(),
      lon: (_data['longitude'] as num).toDouble(),
    );
    if (!mounted) return;
    setState(() {
      _facilitiesSorted = facilities;
      _isLoadingFacilities = false;
    });
  }

  /// "+ Add Helper" — there's no standalone "create helper" flow, so this
  /// jumps to User Management where an admin promotes an existing user's
  /// role, then reloads the (now hopefully longer) helper list on return.
  Future<void> _addHelper() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserManagementView()),
    );
    if (!mounted) return;
    final helpers = await widget.reloadHelpers();
    if (!mounted) return;
    setState(() => _helpers = helpers);
  }

  /// "+ Add Facility" — opens the facility form pre-set to the type this
  /// request actually needs (shelter / distribution_center).
  Future<void> _addFacility() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityFormView(
          controller: _facilityController,
          initialFacilityType: _requiredFacilityType,
        ),
      ),
    );
    if (saved == true) _loadFacilitiesIfNeeded();
  }

  Future<void> _run(Future<void> Function() action, {Map<String, dynamic>? localUpdate}) async {
    setState(() => _isBusy = true);
    await action();
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (localUpdate != null) _data.addAll(localUpdate);
    });
  }

  Future<void> _approve() => _run(
        () => widget.controller.approveRequest(_id),
    localUpdate: {'status': 'approved'},
  );

  Future<void> _reject() async {
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
    await _run(
          () => widget.controller.rejectRequest(_id),
      localUpdate: {'status': 'rejected'},
    );
  }

  Future<void> _setPriority(String priority) => _run(
        () => widget.controller.setPriority(_id, priority),
    localUpdate: {'priority': priority},
  );

  Future<void> _assignHelper(String helperId) => _run(
        () => widget.controller.assignHelper(_id, helperId),
    localUpdate: {'assigned_helper_id': helperId, 'status': 'assigned'},
  );

  Future<void> _assignFacility(String facilityId) => _run(
        () => widget.controller.setFacility(_id, facilityId),
    localUpdate: {'facility_id': facilityId},
  );

  @override
  Widget build(BuildContext context) {
    final priority = _data['priority'] as String? ?? 'medium';
    final account = _data['account'] as Map<String, dynamic>?;
    final assignedHelperId = _data['assigned_helper_id'] as String?;
    final assignedFacilityId = _data['facility_id'] as String?;
    final photoPaths = (_data['photo_paths'] as List?)?.cast<String>() ?? const [];
    final mode = _fulfillmentMode;
    final canAssign = _status == 'approved' || _status == 'assigned' || _status == 'in_progress';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Request Details'), centerTitle: true),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isBusy,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _assistanceType,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusBadge(status: _status),
                      ],
                    ),
                    if (account != null) ...[
                      const SizedBox(height: 6),
                      Text('From: ${account['name'] ?? 'Unknown'} (${account['email'] ?? ''})',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    AssistanceDetailsView(
                      assistanceType: _assistanceType,
                      details: (_data['details'] as Map?)?.cast<String, dynamic>() ?? const {},
                    ),
                    ReviewCard(title: 'Location', value: _data['location_name'] as String? ?? ''),
                    MiniMap(
                      markers: [
                        MapMarkerSpec(
                          point: LatLng((_data['latitude'] as num).toDouble(), (_data['longitude'] as num).toDouble()),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => openDirections(
                            context,
                            latitude: (_data['latitude'] as num).toDouble(),
                            longitude: (_data['longitude'] as num).toDouble(),
                          ),
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Get directions'),
                        ),
                      ),
                    ),
                    if ((_data['damage_description'] as String?)?.trim().isNotEmpty ?? false)
                      ReviewCard(title: 'Description', value: _data['damage_description'] as String),
                    if ((_data['contact_number'] as String?)?.isNotEmpty ?? false)
                      ReviewCard(title: 'Contact number', value: _data['contact_number'] as String),
                    if (_data['created_at'] != null)
                      ReviewCard(title: 'Submitted', value: _formatDate(DateTime.parse(_data['created_at'] as String))),

                    const SizedBox(height: 12),
                    const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    if (photoPaths.isEmpty)
                      const Text('No photos attached', style: TextStyle(color: Colors.grey))
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: photoPaths.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) => NetworkPhotoThumbnail(
                          storagePath: photoPaths[index],
                          repairRequestService: widget.controller.repairRequestService,
                        ),
                      ),

                    const SizedBox(height: 24),
                    const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: _priorities.map((p) {
                        final selected = priority == p;
                        return ChoiceChip(
                          label: Text(p),
                          selected: selected,
                          onSelected: (_) => _setPriority(p),
                          selectedColor: p == 'urgent' ? Colors.red.shade100 : Colors.blue.shade100,
                          labelStyle: TextStyle(
                            color: selected
                                ? (p == 'urgent' ? Colors.red.shade900 : Colors.blue.shade900)
                                : Colors.black87,
                          ),
                        );
                      }).toList(),
                    ),

                    if (_status == 'pending') ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _reject,
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _approve,
                              icon: const Icon(Icons.check, size: 18, color: Colors.white),
                              label: const Text('Approve', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // --- Fulfillment-mode-specific assignment section ---
                    if (canAssign) _buildFulfillmentSection(mode, assignedHelperId, assignedFacilityId),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
              if (_isBusy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFulfillmentSection(
      FulfillmentMode mode,
      String? assignedHelperId,
      String? assignedFacilityId,
      ) {
    switch (mode) {
      case FulfillmentMode.field:
      // Helper travels to the resident — the resident's own location
      // (shown above with "Get directions") is all the helper needs.
        return _buildAssignHelperSection(assignedHelperId);

      case FulfillmentMode.facility:
      // Resident travels to a facility — admin assigns both a helper
      // (to coordinate/receive them) and the facility itself.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssignHelperSection(assignedHelperId),
            const SizedBox(height: 24),
            _buildAssignFacilitySection(assignedFacilityId),
          ],
        );

      case FulfillmentMode.remote:
      // Financial Aid etc. — nobody travels, nothing to assign.
        return Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This request is handled remotely — no helper or facility assignment needed.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildAssignHelperSection(String? assignedHelperId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assign Helper', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _helpers.any((h) => h.id == assignedHelperId) ? assignedHelperId : null,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: [
            ..._helpers.map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
            addNewMenuItem('Add Helper'),
          ],
          onChanged: (value) {
            if (value == kAddNewValue) {
              _addHelper();
              return;
            }
            if (value != null) _assignHelper(value);
          },
          hint: Text(_helpers.isEmpty ? 'No active helpers available' : 'Select a helper'),
        ),
      ],
    );
  }

  Widget _buildAssignFacilitySection(String? assignedFacilityId) {
    final facilityTypeLabel = Facility.typeLabels[_requiredFacilityType] ?? 'Facility';
    final requestPoint = LatLng((_data['latitude'] as num).toDouble(), (_data['longitude'] as num).toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Assign $facilityTypeLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            TextButton.icon(
              onPressed: _addFacility,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text('Add $facilityTypeLabel'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Nearest first, based on the resident\'s location.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (_isLoadingFacilities)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        else if (_facilitiesSorted.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'No active $facilityTypeLabel facilities yet — tap "Add $facilityTypeLabel" above.',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
            ),
          )
        else ...[
          MiniMap(
            interactive: true,
            height: 220,
            markers: [
              MapMarkerSpec(point: requestPoint, color: Colors.red, label: 'Resident'),
              for (final fd in _facilitiesSorted)
                MapMarkerSpec(
                  point: LatLng(fd.facility.latitude, fd.facility.longitude),
                  color: fd.facility.id == assignedFacilityId ? Colors.green : Colors.blue,
                  icon: Icons.home_work,
                  onTap: () => _showFacilitySheet(fd, fd.facility.id == assignedFacilityId),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ..._facilitiesSorted.map(
            (fd) => _FacilityAssignRow(
              data: fd,
              isAssigned: fd.facility.id == assignedFacilityId,
              onAssign: () => _assignFacility(fd.facility.id!),
              onDirections: () => openDirections(context, latitude: fd.facility.latitude, longitude: fd.facility.longitude),
            ),
          ),
        ],
      ],
    );
  }

  void _showFacilitySheet(FacilityWithDistance fd, bool isAssigned) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fd.facility.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${fd.distanceKm.toStringAsFixed(1)} km from the resident', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        openDirections(context, latitude: fd.facility.latitude, longitude: fd.facility.longitude);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isAssigned
                          ? null
                          : () {
                              Navigator.pop(context);
                              _assignFacility(fd.facility.id!);
                            },
                      icon: Icon(isAssigned ? Icons.check : Icons.check_circle_outline, color: Colors.white),
                      label: Text(isAssigned ? 'Assigned' : 'Assign', style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _FacilityAssignRow extends StatelessWidget {
  const _FacilityAssignRow({
    required this.data,
    required this.isAssigned,
    required this.onAssign,
    required this.onDirections,
  });

  final FacilityWithDistance data;
  final bool isAssigned;
  final VoidCallback onAssign;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final facility = data.facility;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAssigned ? Colors.green.withValues(alpha: 0.05) : null,
        border: Border.all(color: isAssigned ? Colors.green.shade300 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facility.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${data.distanceKm.toStringAsFixed(1)} km away'
                  '${facility.capacity != null ? ' · capacity ${facility.capacity}' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDirections,
            icon: const Icon(Icons.directions, size: 20),
            tooltip: 'Directions',
          ),
          if (isAssigned)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.check_circle, color: Colors.green),
            )
          else
            TextButton(onPressed: onAssign, child: const Text('Assign')),
        ],
      ),
    );
  }
}