import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/facility_controller.dart';
import '../../models/facility.dart';
import '../../services/location_service.dart';
import '../../utils/malaysia_geocoding.dart';
import '../../utils/responsive.dart';
import '../../utils/validators.dart';
import '../../widgets/location_search_field.dart';
import '../user/pick_property_location_view.dart';

class FacilityFormView extends StatefulWidget {
  const FacilityFormView({
    super.key,
    required this.controller,
    this.existing,
  });

  final FacilityController controller;
  final Facility? existing;

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
  final TextEditingController _districtController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();

  double? _latitude;
  double? _longitude;

  /// Prefilled from the picked location's reverse geocode (state matched
  /// against known Malaysian names, district taken as-is), both editable.
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

  /// Fills the State (prefers a canonical reverse-geocoded value, falls back
  /// to matching known names against [fallbackText]) and District fields.
  void _applyGeocodedArea({
    String? state,
    String? district,
    String? fallbackText,
  }) {
    final resolvedState =
        (state != null && MalaysiaGeocoder.states.contains(state))
        ? state
        : _deriveStateFromLocationText(fallbackText);
    if (resolvedState != null) _state = resolvedState;
    if (district != null && district.trim().isNotEmpty) {
      _districtController.text = district.trim();
    }
  }

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _capacityController = TextEditingController(
      text: existing?.capacity?.toString() ?? '',
    );
    _contactController = TextEditingController(
      text: existing?.contactNumber ?? '',
    );
    _latitude = existing?.latitude;
    _longitude = existing?.longitude;
    _state = existing?.state;
    _districtController.text = existing?.district ?? '';
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
    _districtController.dispose();
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
      final readable = details.address?.trim();
      if (readable != null && readable.isNotEmpty) {
        _locationNameController.text = readable;
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = readable;
        }
      }
      _applyGeocodedArea(
        state: details.state,
        district: details.district,
        fallbackText: readable,
      );
    });
  }

  Future<void> _pickOnMap() async {
    final initial = (_latitude != null && _longitude != null)
        ? LatLng(_latitude!, _longitude!)
        : null;
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => PickPropertyLocationView(initialLocation: initial),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latitude = picked.point.latitude;
      _longitude = picked.point.longitude;
      final address = picked.geocode?.address?.trim();
      if (address != null && address.isNotEmpty) {
        _locationNameController.text = address;
        if (_addressController.text.trim().isEmpty) {
          _addressController.text = address;
        }
      }
      _applyGeocodedArea(
        state: picked.geocode?.state,
        district: picked.geocode?.district,
        fallbackText: address,
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a location for this facility.'),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    final facility = Facility(
      id: widget.existing?.id,
      name: _nameController.text.trim(),
      // Admin-managed evacuation centers are always shelters. Keeping this
      // fixed here also converts any legacy facility when it is edited.
      facilityType: 'shelter',
      latitude: _latitude!,
      longitude: _longitude!,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      state: _state,
      district: _districtController.text.trim().isEmpty
          ? null
          : _districtController.text.trim(),
      capacity: int.tryParse(_capacityController.text.trim()),
      contactNumber: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      isActive: _isActive,
    );

    var success = false;
    try {
      if (_isEditing) {
        await widget.controller.updateFacility(
          widget.existing!.id!,
          facility.toJson(),
        );
        success = true;
      } else {
        success = await widget.controller.createFacility(facility);
      }
    } catch (_) {
      success = false;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the facility. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isSaving,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Facility' : 'Add Facility'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.responsive(
                    mobile: 700,
                    tablet: 800,
                    desktop: 900,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Facility name',
                          hintText: 'e.g. Dewan Komuniti Cyberjaya',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a facility name.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LocationSearchField(
                        controller: _locationNameController,
                        focusNode: _locationFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Search location',
                          hintText: 'Type an address, or tap for nearby places',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        onManualEdit: () {
                          _latitude = null;
                          _longitude = null;
                        },
                        onCoordinates: (lat, lng) => setState(() {
                          _latitude = lat;
                          _longitude = lng;
                          if (_addressController.text.trim().isEmpty) {
                            _addressController.text =
                                _locationNameController.text;
                          }
                        }),
                        onArea: ({state, district, postcode}) => setState(
                          () => _applyGeocodedArea(
                            state: state,
                            district: district,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                            _isLocating
                                ? 'Locating...'
                                : 'Use Current Location',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _isLocating ? null : _pickOnMap,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Pick on map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (_latitude != null && _longitude != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Coordinates: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        // Re-seed when a picked location changes _state from code.
                        key: ValueKey(_state),
                        initialValue: _state,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: MalaysiaGeocoder.states
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _state = value),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _districtController,
                        decoration: const InputDecoration(
                          labelText: 'District (optional)',
                          hintText: 'e.g. Petaling',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText:
                              'Address (optional, shown to residents/helpers)',
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
                        validator: validatePhoneNumber,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text(
                          'Inactive facilities cannot be newly assigned',
                        ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isSaving
                                ? 'Saving...'
                                : (_isEditing
                                      ? 'Save changes'
                                      : 'Add facility'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
