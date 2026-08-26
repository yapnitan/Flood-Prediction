import 'package:flutter/material.dart';

import '../../controllers/facility_controller.dart';
import '../../controllers/shelter_occupancy_controller.dart';
import '../../models/facility.dart';
import '../../models/shelter_occupancy_report.dart';
import '../../services/facility_service.dart';
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

  bool _isLoading = true;
  List<Facility> _shelters = [];
  Map<String, ShelterOccupancyReport> _latestByFacility = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shelters = await _facilityController.getAssignableFacilities('shelter');
    final latest = await _occupancyController.getLatestPerFacility();
    if (!mounted) return;
    setState(() {
      _shelters = shelters;
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
                    child: _shelters.isEmpty
                        ? const EmptyState(
                            icon: Icons.night_shelter_outlined,
                            title: 'No active shelters yet',
                            subtitle: 'An admin needs to add one under Facilities first.',
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
            if (latest == null)
              const Text('No occupancy logged yet', style: TextStyle(color: Colors.grey, fontSize: 13))
            else ...[
              Text('Current occupancy: ${latest!.totalVictims ?? 0} people', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                'Resource cost: RM ${(latest!.resourceCost ?? latest!.calculatedResourceCost).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.teal),
              ),
            ],
          ],
        ),
      ),
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
  }

  @override
  void dispose() {
    _adults.dispose();
    _children.dispose();
    _elderly.dispose();
    _infants.dispose();
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await widget.controller.record(ShelterOccupancyReport(
      facilityId: widget.shelter.id!,
      adults: int.tryParse(_adults.text.trim()) ?? 0,
      children: int.tryParse(_children.text.trim()) ?? 0,
      elderly: int.tryParse(_elderly.text.trim()) ?? 0,
      infants: int.tryParse(_infants.text.trim()) ?? 0,
      personsWithDisabilities: int.tryParse(_pwd.text.trim()) ?? 0,
    ));
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context, ok);
  }

  Widget _countField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
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
