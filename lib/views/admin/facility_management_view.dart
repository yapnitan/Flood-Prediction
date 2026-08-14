import 'package:flutter/material.dart';
import '../../controllers/facility_controller.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';
import '../../utils/responsive.dart';
import 'facility_form_view.dart';

class FacilityManagementView extends StatefulWidget {
  const FacilityManagementView({super.key});

  @override
  State<FacilityManagementView> createState() => _FacilityManagementViewState();
}

class _FacilityManagementViewState extends State<FacilityManagementView> {
  final _controller = FacilityController(FacilityService());
  late Future<List<Facility>> _facilitiesFuture;
  String _typeFilter = 'all';

  static const _typeOptions = ['all', 'shelter', 'distribution_center', 'medical_station'];

  @override
  void initState() {
    super.initState();
    _facilitiesFuture = _controller.getAllFacilities();
  }

  Future<void> _refresh() async {
    setState(() => _facilitiesFuture = _controller.getAllFacilities());
    await _facilitiesFuture;
  }

  Future<void> _openForm({Facility? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityFormView(controller: _controller, existing: existing),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _toggleActive(Facility facility) async {
    await _controller.setActive(facility.id!, !facility.isActive);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add facility',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
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
                    child: FutureBuilder<List<Facility>>(
                      future: _facilitiesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Could not load facilities.'));
                        }

                        var facilities = snapshot.data ?? [];
                        if (_typeFilter != 'all') {
                          facilities = facilities.where((f) => f.facilityType == _typeFilter).toList();
                        }

                        if (facilities.isEmpty) {
                          return LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: const Center(child: Text('No facilities yet. Tap + to add one.')),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          itemCount: facilities.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _FacilityCard(
                            facility: facilities[index],
                            onTap: () => _openForm(existing: facilities[index]),
                            onToggleActive: () => _toggleActive(facilities[index]),
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
        itemCount: _typeOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = _typeOptions[index];
          final selected = _typeFilter == type;
          final label = type == 'all' ? 'All' : Facility.typeLabels[type]!;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => setState(() => _typeFilter = type),
            selectedColor: Colors.blue.shade100,
            labelStyle: TextStyle(color: selected ? Colors.blue.shade900 : Colors.black87),
          );
        },
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({
    required this.facility,
    required this.onTap,
    required this.onToggleActive,
  });

  final Facility facility;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: facility.isActive ? null : Colors.grey.withValues(alpha: 0.05),
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
                    facility.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Switch(value: facility.isActive, onChanged: (_) => onToggleActive()),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(_iconFor(facility.facilityType), size: 14, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text(facility.typeLabel, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
              ],
            ),
            if (facility.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      facility.address!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (facility.capacity != null) ...[
              const SizedBox(height: 4),
              Text('Capacity: ${facility.capacity}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'shelter':
        return Icons.home_work_outlined;
      case 'distribution_center':
        return Icons.inventory_2_outlined;
      case 'medical_station':
        return Icons.local_hospital_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}