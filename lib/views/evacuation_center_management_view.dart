import 'package:flutter/material.dart';
import '../models/evacuation_center.dart';
import '../services/evacuation_center_service.dart';
import '../utils/responsive.dart';

class EvacuationCenterManagementView extends StatefulWidget {
  const EvacuationCenterManagementView({super.key});

  @override
  State<EvacuationCenterManagementView> createState() =>
      _EvacuationCenterManagementViewState();
}

class _EvacuationCenterManagementViewState
    extends State<EvacuationCenterManagementView> {
  final EvacuationCenterService _service = EvacuationCenterService();
  late List<EvacuationCenter> _centers;
  String _searchQuery = '';
  String _selectedState = 'All';
  String _selectedStatus = 'All';

  final List<String> _states = [
    'All',
    'Selangor',
    'Johor',
    'Pahang',
    'Kelantan',
    'Terengganu',
    'Perak',
    'Sarawak',
    'Kedah',
    'Sabah',
    'Negeri Sembilan',
    'Pulau Pinang',
    'Melaka',
    'WP Kuala Lumpur',
    'Perlis',
  ];

  final List<String> _statuses = ['All', 'Active', 'Standby', 'Full'];

  @override
  void initState() {
    super.initState();
    _refreshCenters();
  }

  void _refreshCenters() {
    setState(() {
      _centers = _service.getAllCenters();
    });
  }

  List<EvacuationCenter> get _filteredCenters {
    return _centers.where((center) {
      final matchesQuery = _searchQuery.isEmpty ||
          center.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          center.district.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesState =
          _selectedState == 'All' || center.state == _selectedState;
      final matchesStatus =
          _selectedStatus == 'All' || center.status == _selectedStatus;
      return matchesQuery && matchesState && matchesStatus;
    }).toList();
  }

  void _showAddEditDialog([EvacuationCenter? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final stateController = TextEditingController(text: existing?.state ?? 'Selangor');
    final districtController = TextEditingController(text: existing?.district ?? '');
    final capacityController =
        TextEditingController(text: existing != null ? '${existing.capacity}' : '300');
    final occupantsController =
        TextEditingController(text: existing != null ? '${existing.currentOccupants}' : '0');
    final contactPersonController =
        TextEditingController(text: existing?.contactPerson ?? '');
    final contactPhoneController =
        TextEditingController(text: existing?.contactPhone ?? '');
    String status = existing?.status ?? 'Active';

    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulWidget(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add Evacuation Center' : 'Edit Evacuation Center',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Center Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _states.contains(stateController.text)
                                    ? stateController.text
                                    : 'Selangor',
                                items: _states
                                    .where((s) => s != 'All')
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) stateController.text = val;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'State',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: districtController,
                                decoration: const InputDecoration(
                                  labelText: 'District',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: capacityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Capacity',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    v == null || int.tryParse(v) == null ? 'Number required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: occupantsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Current Occupants',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    v == null || int.tryParse(v) == null ? 'Number required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Standby', child: Text('Standby')),
                            DropdownMenuItem(value: 'Full', child: Text('Full')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => status = val);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactPersonController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Person',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final newCenter = EvacuationCenter(
                        id: existing?.id ?? 'ec-${DateTime.now().millisecondsSinceEpoch}',
                        name: nameController.text.trim(),
                        state: stateController.text,
                        district: districtController.text.trim(),
                        capacity: int.parse(capacityController.text.trim()),
                        currentOccupants: int.parse(occupantsController.text.trim()),
                        status: status,
                        contactPerson: contactPersonController.text.trim(),
                        contactPhone: contactPhoneController.text.trim(),
                        latitude: existing?.latitude ?? 3.1390,
                        longitude: existing?.longitude ?? 101.6869,
                      );

                      if (existing == null) {
                        _service.addCenter(newCenter);
                      } else {
                        _service.updateCenter(newCenter);
                      }
                      Navigator.pop(context);
                      _refreshCenters();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existing == null
                                ? 'Evacuation center added successfully.'
                                : 'Evacuation center updated successfully.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(existing == null ? 'Add Center' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCenter(EvacuationCenter center) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to remove "${center.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              _service.deleteCenter(center.id);
              Navigator.pop(context);
              _refreshCenters();
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Evacuation center removed.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _centers.where((c) => c.status == 'Active').length;
    final standbyCount = _centers.where((c) => c.status == 'Standby').length;
    final fullCount = _centers.where((c) => c.status == 'Full').length;
    final totalCapacity = _centers.fold<int>(0, (sum, c) => sum + c.capacity);
    final totalOccupants = _centers.fold<int>(0, (sum, c) => sum + c.currentOccupants);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Evacuation Center Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            context.responsive(mobile: 16, tablet: 24, desktop: 32),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(mobile: 700, tablet: 900, desktop: 1100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Summary Header
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 700 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          _SummaryBadge(
                            title: 'Total Centers',
                            value: '${_centers.length}',
                            icon: Icons.other_houses,
                            color: Colors.blue,
                          ),
                          _SummaryBadge(
                            title: 'Active',
                            value: '$activeCount',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                          _SummaryBadge(
                            title: 'Standby',
                            value: '$standbyCount',
                            icon: Icons.hourglass_empty,
                            color: Colors.orange,
                          ),
                          _SummaryBadge(
                            title: 'Total Occupancy',
                            value: '$totalOccupants / $totalCapacity',
                            icon: Icons.people_outline,
                            color: Colors.purple,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Search and Filters Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: const InputDecoration(
                                  hintText: 'Search center name or district...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(10)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showAddEditDialog(),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Add Center', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedState,
                                items: _states
                                    .map((s) => DropdownMenuItem(value: s, child: Text('State: $s')))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedState = val);
                                },
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                items: _statuses
                                    .map((s) => DropdownMenuItem(value: s, child: Text('Status: $s')))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedStatus = val);
                                },
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Evacuation Center List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredCenters.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final center = _filteredCenters[index];
                      Color statusColor;
                      switch (center.status) {
                        case 'Active':
                          statusColor = Colors.green;
                          break;
                        case 'Standby':
                          statusColor = Colors.orange;
                          break;
                        case 'Full':
                          statusColor = Colors.red;
                          break;
                        default:
                          statusColor = Colors.grey;
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.other_houses, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        center.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '${center.district}, ${center.state}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    center.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Occupancy',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          Text(
                                            '${center.currentOccupants} / ${center.capacity}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: center.occupancyRate,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            center.occupancyRate >= 0.9
                                                ? Colors.red
                                                : (center.occupancyRate >= 0.7
                                                    ? Colors.orange
                                                    : Colors.blue),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                      onPressed: () => _showAddEditDialog(center),
                                      tooltip: 'Edit Center',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _deleteCenter(center),
                                      tooltip: 'Delete Center',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryBadge({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
