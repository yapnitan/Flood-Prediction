import 'package:flutter/material.dart';

import '../../controllers/facility_controller.dart';
import '../../controllers/helper_assignment_controller.dart';
import '../../controllers/shelter_occupancy_controller.dart';
import '../../models/facility.dart';
import '../../models/helper_district_assignment.dart';
import '../../models/shelter_occupancy_report.dart';
import '../../services/facility_service.dart';
import '../../services/helper_assignment_service.dart';
import '../../services/shelter_occupancy_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';

/// Resource Consumption Cost entry point (Task/asset report §23/§39): a
/// helper picks an active shelter and logs current demographic headcounts;
/// the app calculates a resource cost from a fixed per-person rate table
/// and feeds it into the admin's Economic Loss Dashboard.
class ShelterOccupancyView extends StatefulWidget {
  const ShelterOccupancyView({super.key});

  @override
  State<ShelterOccupancyView> createState() => _ShelterOccupancyViewState();
}

class _ShelterOccupancyViewState extends State<ShelterOccupancyView> {
  final _facilityController = FacilityController(FacilityService());
  final _occupancyController = ShelterOccupancyController(ShelterOccupancyService());
  final _assignmentController =
      HelperAssignmentController(HelperAssignmentService());

  bool _isLoading = true;
  List<Facility> _shelters = [];
  Map<String, ShelterOccupancyReport> _latestByFacility = {};
  bool _hasActiveAssignment = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _facilityController.getAssignableFacilities('shelter'),
      _occupancyController.getLatestPerFacility(),
      _assignmentController.getMyAssignments(),
    ]);
    if (!mounted) return;

    final allShelters = results[0] as List<Facility>;
    final latest = results[1] as Map<String, ShelterOccupancyReport>;
    final assignments = (results[2] as List<HelperDistrictAssignment>)
        .where((a) => a.isActive)
        .toList();

    // A helper only handles shelters that sit in one of their active
    // state/district assignments — the RLS on shelter_occupancy_report
    // (0040) enforces the same rule server-side.
    final areas = assignments
        .map((a) => '${a.state.trim().toLowerCase()}|${a.district.trim().toLowerCase()}')
        .toSet();
    final scopedShelters = allShelters.where((f) {
      final state = (f.state ?? '').trim().toLowerCase();
      final district = (f.district ?? '').trim().toLowerCase();
      return areas.contains('$state|$district');
    }).toList();

    setState(() {
      _hasActiveAssignment = assignments.isNotEmpty;
      _shelters = scopedShelters;
      _latestByFacility = latest;
      _isLoading = false;
    });
  }

  Future<void> _openEntryForm(Facility shelter) async {
    final existing = _latestByFacility[shelter.id];
    final recorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OccupancyEntrySheet(
        shelter: shelter,
        existing: existing,
        controller: _occupancyController,
      ),
    );
    if (recorded == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: !_hasActiveAssignment
                        ? const EmptyState(
                            icon: Icons.location_off_outlined,
                            title: 'No district assigned',
                            subtitle:
                                'An admin needs to assign you to a state/district '
                                'before you can view or record shelter occupancy.',
                          )
                        : _shelters.isEmpty
                        ? const EmptyState(
                            icon: Icons.night_shelter_outlined,
                            title: 'No shelters in your area',
                            subtitle:
                                'There are no active shelters in your assigned '
                                'district(s) yet.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _shelters.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final shelter = _shelters[index];
                              final latest = _latestByFacility[shelter.id];
                              return _ShelterCard(
                                shelter: shelter,
                                latest: latest,
                                onTap: () => _openEntryForm(shelter),
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

class _ShelterCard extends StatelessWidget {
  const _ShelterCard({required this.shelter, required this.latest, required this.onTap});

  final Facility shelter;
  final ShelterOccupancyReport? latest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shelter.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            if (shelter.address != null) ...[
              const SizedBox(height: 4),
              Text(shelter.address!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            if (latest == null) ...[
              Text(
                shelter.capacity != null
                    ? 'No occupancy logged yet · capacity ${shelter.capacity}'
                    : 'No occupancy logged yet',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ] else
              _OccupancySummary(shelter: shelter, latest: latest!),
          ],
        ),
      ),
    );
  }
}

class _OccupancySummary extends StatelessWidget {
  const _OccupancySummary({required this.shelter, required this.latest});

  final Facility shelter;
  final ShelterOccupancyReport latest;

  @override
  Widget build(BuildContext context) {
    final occupancy = latest.totalVictims ?? latest.headcount;
    final capacity = shelter.capacity;
    final over = capacity != null && occupancy > capacity;
    final fraction = (capacity != null && capacity > 0)
        ? (occupancy / capacity).clamp(0.0, 1.0)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              capacity != null
                  ? 'Occupancy: $occupancy / $capacity'
                  : 'Occupancy: $occupancy people',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (over) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Over by ${occupancy - capacity}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (fraction != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                over
                    ? Colors.red
                    : (fraction > 0.85 ? Colors.orange : Colors.teal),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Resource cost: RM ${(latest.resourceCost ?? latest.calculatedResourceCost).toStringAsFixed(2)}'
          ' · ${latest.days} day${latest.days == 1 ? '' : 's'} stay',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }
}

/// Live "total headcount vs shelter capacity" readout on the entry sheet.
/// A warning only — a shelter can legitimately be over capacity in a
/// disaster, so saving is never blocked.
class _CapacityIndicator extends StatelessWidget {
  const _CapacityIndicator({required this.headcount, required this.capacity});

  final int headcount;
  final int? capacity;

  @override
  Widget build(BuildContext context) {
    if (capacity == null) {
      return Text(
        'Total: $headcount people (no capacity set for this shelter)',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    final over = headcount > capacity!;
    final fraction = capacity! > 0 ? (headcount / capacity!).clamp(0.0, 1.0) : 1.0;
    final color = over
        ? Colors.red
        : (fraction > 0.85 ? Colors.orange : Colors.teal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Total: $headcount / $capacity',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
            if (over) ...[
              const SizedBox(width: 8),
              Text(
                'over capacity by ${headcount - capacity!}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _OccupancyEntrySheet extends StatefulWidget {
  const _OccupancyEntrySheet({required this.shelter, required this.existing, required this.controller});

  final Facility shelter;
  final ShelterOccupancyReport? existing;
  final ShelterOccupancyController controller;

  @override
  State<_OccupancyEntrySheet> createState() => _OccupancyEntrySheetState();
}

class _OccupancyEntrySheetState extends State<_OccupancyEntrySheet> {
  late final TextEditingController _adults;
  late final TextEditingController _children;
  late final TextEditingController _elderly;
  late final TextEditingController _infants;
  late final TextEditingController _pwd;
  late final TextEditingController _days;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _adults = TextEditingController(text: '${e?.adults ?? 0}');
    _children = TextEditingController(text: '${e?.children ?? 0}');
    _elderly = TextEditingController(text: '${e?.elderly ?? 0}');
    _infants = TextEditingController(text: '${e?.infants ?? 0}');
    _pwd = TextEditingController(text: '${e?.personsWithDisabilities ?? 0}');
    _days = TextEditingController(text: '${e?.days ?? 1}');
  }

  @override
  void dispose() {
    _adults.dispose();
    _children.dispose();
    _elderly.dispose();
    _infants.dispose();
    _pwd.dispose();
    _days.dispose();
    super.dispose();
  }

  int _value(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  int get _headcount =>
      _value(_adults) + _value(_children) + _value(_elderly) + _value(_infants) + _value(_pwd);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await widget.controller.record(ShelterOccupancyReport(
      facilityId: widget.shelter.id!,
      adults: _value(_adults),
      children: _value(_children),
      elderly: _value(_elderly),
      infants: _value(_infants),
      personsWithDisabilities: _value(_pwd),
      days: _value(_days) < 1 ? 1 : _value(_days),
    ));
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save — you can only record occupancy for shelters in '
            'your assigned district.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, ok);
  }

  Widget _countField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.shelter.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Enter current headcounts — this replaces the shelter\'s last logged snapshot.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _countField('Adults', _adults),
            _countField('Children', _children),
            _countField('Elderly', _elderly),
            _countField('Infants', _infants),
            _countField('Persons with disabilities', _pwd),
            _countField('Days of stay (for resource cost)', _days),
            _CapacityIndicator(headcount: _headcount, capacity: widget.shelter.capacity),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text(
                  _isSaving ? 'Saving...' : 'Save',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
