import 'package:flutter/material.dart';
import '../../constants/nearby_locations.dart';
import '../../controllers/facility_controller.dart';
import '../../models/facility.dart';
import '../../services/location_service.dart';
import '../../widgets/selectable_chip.dart';

class FacilityFormView extends StatefulWidget {
  const FacilityFormView({super.key, required this.controller, this.existing, this.initialFacilityType});

  final FacilityController controller;
  final Facility? existing;

  /// Pre-selects the facility type when creating (ignored when editing) —
  /// used by the admin's "+ Add Facility" shortcut from a request that
  /// already knows which type it needs (e.g. 'shelter').
  final String? initialFacilityType;

  @override
  State<FacilityFormView> createState() => _FacilityFormViewState();
}

class _FacilityFormViewState extends State<FacilityFormView> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _capacityController;
  late final TextEditingController _contactController;
  final TextEditingController _locationNameController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();

  String _facilityType = 'shelter';
  double? _latitude;
  double? _longitude;

  /// Not entered directly — derived from whichever location text the admin
  /// picked (autocomplete suggestion or reverse-geocoded current location),
  /// by matching it against known Malaysian state names.
  String? _state;
  bool _isActive = true;
  bool _isLocating = false;
  bool _isSaving = false;

  // Malaysian states/federal territories, plus common aliases as they show
  // up in free-text place names (e.g. Nominatim's "Penang" vs. the official
  // "Pulau Pinang").
  static const _stateAliases = <String, String>{
    'Selangor': 'Selangor',
    'Johor': 'Johor',
    'Pahang': 'Pahang',
    'Kelantan': 'Kelantan',
    'Terengganu': 'Terengganu',
    'Perak': 'Perak',
    'Sarawak': 'Sarawak',
    'Kedah': 'Kedah',
    'Sabah': 'Sabah',
    'Negeri Sembilan': 'Negeri Sembilan',
    'Pulau Pinang': 'Pulau Pinang',
    'Penang': 'Pulau Pinang',
    'Melaka': 'Melaka',
    'Malacca': 'Melaka',
    'Perlis': 'Perlis',
    'Putrajaya': 'WP Putrajaya',
    'Labuan': 'WP Labuan',
    'Kuala Lumpur': 'WP Kuala Lumpur',
  };

  static String? _deriveStateFromLocationText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final lower = text.toLowerCase();
    for (final alias in _stateAliases.entries) {
      if (lower.contains(alias.key.toLowerCase())) return alias.value;
    }
    return null;
  }

  bool get _isEditing => widget.existing != null;

  static const _facilityTypes = ['shelter', 'distribution_center', 'medical_station'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _capacityController = TextEditingController(text: existing?.capacity?.toString() ?? '');
    _contactController = TextEditingController(text: existing?.contactNumber ?? '');
    _facilityType = existing?.facilityType ?? widget.initialFacilityType ?? 'shelter';
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    _state = existing?.state;
    _isActive = existing?.isActive ?? true;
    if (existing?.address != null) {
      _locationNameController.text = existing!.address!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _contactController.dispose();
    _locationNameController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    final details = await _locationService.getCurrentLocationDetails();
    if (!mounted) return;

    if (details == null) {
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to access current location.')),
      );
      return;
    }

    setState(() {
      _isLocating = false;
      _latitude = details.position.latitude;
      _longitude = details.position.longitude;
      final readable = details.address?.trim();
      if (readable != null && readable.isNotEmpty) {
        _locationNameController.text = readable;
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = readable;
        }
        _state = _deriveStateFromLocationText(readable);
      }
    });
  }

  void _selectLocation(ReportLocation location) {
    _locationNameController.text = location.name;
    _latitude = location.latitude;
    _longitude = location.longitude;
    _state = _deriveStateFromLocationText(location.name);
    if (_addressController.text.trim().isEmpty) {
      _addressController.text = location.name;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a location for this facility.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final facility = Facility(
      id: widget.existing?.id,
      name: _nameController.text.trim(),
      facilityType: _facilityType,
      latitude: _latitude!,
      longitude: _longitude!,
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      state: _state,
      capacity: int.tryParse(_capacityController.text.trim()),
      contactNumber: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      isActive: _isActive,
    );

    bool success;
    if (_isEditing) {
      await widget.controller.updateFacility(widget.existing!.id!, facility.toJson());
      success = true;
    } else {
      success = await widget.controller.createFacility(facility);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the facility. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Facility' : 'Add Facility'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Facility Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _facilityTypes.map((type) {
                    return SelectableChip(
                      label: Facility.typeLabels[type]!,
                      selected: _facilityType == type,
                      onTap: () => setState(() => _facilityType = type),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Facility name',
                    hintText: 'e.g. Dewan Komuniti Cyberjaya',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a facility name.' : null,
                ),
                const SizedBox(height: 20),
                const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                RawAutocomplete<ReportLocation>(
                  textEditingController: _locationNameController,
                  focusNode: _locationFocusNode,
                  optionsBuilder: (textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    return kNearbyLocations.where(
                          (location) => query.isEmpty || location.name.toLowerCase().contains(query),
                    );
                  },
                  onSelected: _selectLocation,
                  displayStringForOption: (location) => location.name,
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 250, maxWidth: 600),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: options.map((location) {
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                              title: Text(location.name),
                              onTap: () => onSelected(location),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Search location',
                      hintText: 'Tap to see nearby locations',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.my_location, size: 18),
                    label: Text(_isLocating ? 'Locating...' : 'Use Current Location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Coordinates: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    _state != null ? 'State: $_state' : 'State: could not be detected from this location',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional, shown to residents/helpers)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number (optional)',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive facilities cannot be newly assigned'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isSaving ? 'Saving...' : (_isEditing ? 'Save changes' : 'Add facility'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
}