import 'package:flutter/material.dart';
import '../../controllers/facility_controller.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/malaysia_geocoding.dart';
import '../../utils/responsive.dart';
import '../../widgets/adaptive_search_filter_header.dart';
import 'facility_form_view.dart';

class FacilityManagementView extends StatefulWidget {
  const FacilityManagementView({super.key});

  @override
  State<FacilityManagementView> createState() => _FacilityManagementViewState();
}

class _FacilityManagementViewState extends State<FacilityManagementView> {
  final _controller = FacilityController(FacilityService());
  final _searchController = TextEditingController();
  late Future<List<Facility>> _facilitiesFuture;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _stateFilter = 'all';

  static const _statusOptions = ['all', 'active', 'inactive'];

  static String _statusLabel(String status) => switch (status) {
    'active' => 'Active',
    'inactive' => 'Inactive',
    _ => 'All',
  };

  @override
  void initState() {
    super.initState();
    _facilitiesFuture = _controller.getAllFacilities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _facilitiesFuture = _controller.getAllFacilities();
    });
    await _facilitiesFuture;
  }

  Future<void> _openForm({Facility? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FacilityFormView(controller: _controller, existing: existing),
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
              maxWidth: context.responsive(
                mobile: 700,
                tablet: 900,
                desktop: 1100,
              ),
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: AdaptiveSearchFilterHeader(
                      searchField: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(
                          () => _searchQuery = value.trim().toLowerCase(),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search shelters by name',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      portraitFilters: [
                        _buildStatusFilterBar(),
                        _buildStateFilterDropdown(),
                      ],
                      sheetTitle: 'Filter facilities',
                      activeFilterCount:
                          (_statusFilter == 'all' ? 0 : 1) +
                          (_stateFilter == 'all' ? 0 : 1),
                      sheetBuilder: (context, setSheetState) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final status in _statusOptions)
                                ChoiceChip(
                                  label: Text(_statusLabel(status)),
                                  selected: _statusFilter == status,
                                  onSelected: (_) {
                                    setState(() => _statusFilter = status);
                                    setSheetState(() {});
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'State',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey('sheet-state-$_stateFilter'),
                            initialValue: _stateFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _stateOptions
                                .map(
                                  (state) => DropdownMenuItem(
                                    value: state,
                                    child: Text(_stateLabel(state)),
                                  ),
                                )
                                .toList(),
                            onChanged: (state) {
                              if (state == null) return;
                              setState(() => _stateFilter = state);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<Facility>>(
                      future: _facilitiesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Could not load facilities.'),
                          );
                        }

                        var facilities = snapshot.data ?? [];
                        if (_statusFilter != 'all') {
                          final showActive = _statusFilter == 'active';
                          facilities = facilities
                              .where(
                                (facility) => facility.isActive == showActive,
                              )
                              .toList();
                        }
                        if (_stateFilter != 'all') {
                          facilities = facilities
                              .where(
                                (facility) => facility.state == _stateFilter,
                              )
                              .toList();
                        }
                        if (_searchQuery.isNotEmpty) {
                          facilities = facilities
                              .where(
                                (facility) => facility.name
                                    .toLowerCase()
                                    .contains(_searchQuery),
                              )
                              .toList();
                        }

                        if (facilities.isEmpty) {
                          return LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No shelters match your search.'
                                            : _statusFilter == 'active'
                                            ? 'No active facilities.'
                                            : _statusFilter == 'inactive'
                                            ? 'No inactive facilities.'
                                            : 'No facilities yet. Tap + to add one.',
                                      ),
                                    ),
                                  ),
                                ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          itemCount: facilities.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _FacilityCard(
                            facility: facilities[index],
                            onTap: () => _openForm(existing: facilities[index]),
                            onToggleActive: () =>
                                _toggleActive(facilities[index]),
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

  Widget _buildStatusFilterBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _statusOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statusOptions[index];
          final selected = _statusFilter == status;
          return ChoiceChip(
            label: Text(_statusLabel(status)),
            selected: selected,
            onSelected: (_) => setState(() => _statusFilter = status),
            selectedColor: Colors.blue.shade100,
            labelStyle: TextStyle(
              color: selected ? Colors.blue.shade900 : Colors.black87,
            ),
          );
        },
      ),
    );
  }

  List<String> get _stateOptions => ['all', ...MalaysiaGeocoder.states];

  String _stateLabel(String state) => state == 'all' ? 'All states' : state;

  Widget _buildStateFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey('page-state-$_stateFilter'),
        initialValue: _stateFilter,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'State',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: _stateOptions
            .map(
              (state) => DropdownMenuItem(
                value: state,
                child: Text(_stateLabel(state)),
              ),
            )
            .toList(),
        onChanged: (state) {
          if (state != null) setState(() => _stateFilter = state);
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Switch(
                  value: facility.isActive,
                  onChanged: (_) => onToggleActive(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _iconFor(facility.facilityType),
                  size: 14,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  facility.typeLabel,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
            if (facility.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
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
              Text(
                'Capacity: ${groupThousands(facility.capacity.toString())}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
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
