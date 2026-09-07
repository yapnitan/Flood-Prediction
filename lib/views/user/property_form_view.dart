import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/property_controller.dart';
import '../../models/property.dart';
import '../../services/location_service.dart';
import '../../utils/malaysia_geocoding.dart';
import '../../utils/responsive.dart';
import '../../widgets/location_search_field.dart';
import '../../widgets/selectable_chip.dart';
import 'pick_property_location_view.dart';

/// Property types a user can pick from when adding a saved address —
/// previously came from assistance_field_spec.dart (repair-request-only,
/// now removed); kept as a small local list since Property has no other
/// source for this.
const List<String> propertyTypeOptions = [
  'House',
  'Apartment/Condo',
  'Shophouse',
  'Other',
];

class PropertyFormView extends StatefulWidget {
  const PropertyFormView({super.key, required this.controller, this.existing});

  final PropertyController controller;

  /// When set, the form opens pre-filled to edit this property instead of
  /// creating a new one.
  final Property? existing;

  @override
  State<PropertyFormView> createState() => _PropertyFormViewState();
}

class _PropertyFormViewState extends State<PropertyFormView> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _floorsController = TextEditingController();
  final TextEditingController _estimatedValueController =
      TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();

  String? _propertyType;
  double? _latitude;
  double? _longitude;

  /// State is a fixed dropdown, district free text — same pattern already
  /// used for the risk simulator's property location (create_simulation_view.dart),
  /// rather than trying to auto-derive district from reverse geocoding
  /// (nothing in this project resolves a coordinate to a Malaysian district
  /// reliably yet).
  late String _state;
  bool _isLocating = false;
  bool _isSaving = false;

  static const List<String> _labelSuggestions = ['Home', 'Work', 'Other'];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _state = existing?.state ?? MalaysiaGeocoder.states.first;
    if (existing == null) return;
    _labelController.text = existing.label ?? '';
    _addressController.text = existing.address ?? '';
    _districtController.text = existing.district ?? '';
    _postcodeController.text = existing.postcode ?? '';
    _floorsController.text = existing.floors?.toString() ?? '';
    _estimatedValueController.text = existing.estimatedValue?.toString() ?? '';
    _propertyType = existing.propertyType;
    _latitude = existing.lat;
    _longitude = existing.lng;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _labelController.dispose();
    _districtController.dispose();
    _postcodeController.dispose();
    _floorsController.dispose();
    _estimatedValueController.dispose();
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
        _addressController.text = readable;
      }
      _applyGeocodedFields(
        state: details.state,
        district: details.district,
        postcode: details.postcode,
      );
    });
  }

  /// Fills in state/district/postcode from a reverse-geocode result —
  /// still always editable afterward, since Nominatim's district
  /// classification isn't reliable enough to lock the field.
  void _applyGeocodedFields({
    String? state,
    String? district,
    String? postcode,
  }) {
    if (state != null && MalaysiaGeocoder.states.contains(state)) {
      _state = state;
    }
    if (district != null && district.trim().isNotEmpty) {
      _districtController.text = district.trim();
    }
    if (postcode != null && postcode.trim().isNotEmpty) {
      _postcodeController.text = postcode.trim();
    }
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
        _addressController.text = address;
      }
      _applyGeocodedFields(
        state: picked.geocode?.state,
        district: picked.geocode?.district,
        postcode: picked.geocode?.postcode,
      );
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a location for this property.'),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    final property = Property(
      label: _labelController.text.trim().isEmpty
          ? null
          : _labelController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      lat: _latitude!,
      lng: _longitude!,
      state: _state,
      district: _districtController.text.trim().isEmpty
          ? null
          : _districtController.text.trim(),
      postcode: _postcodeController.text.trim().isEmpty
          ? null
          : _postcodeController.text.trim(),
      propertyType: _propertyType,
      floors: int.tryParse(_floorsController.text.trim()),
      estimatedValue: double.tryParse(_estimatedValueController.text.trim()),
    );

    final saved = _isEditing
        ? await widget.controller.updateProperty(widget.existing!.id!, property)
        : await widget.controller.createProperty(property);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved != null) {
      Navigator.of(context).pop(saved);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the property. Please try again.'),
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
          title: Text(_isEditing ? 'Edit Property' : 'Add Property'),
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
                      const Text(
                        'Label',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: _labelSuggestions.map((label) {
                          return SelectableChip(
                            label: label,
                            selected: _labelController.text == label,
                            onTap: () =>
                                setState(() => _labelController.text = label),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _labelController,
                        decoration: const InputDecoration(
                          labelText: 'Name this address',
                          hintText: 'e.g. Home, Work, or a custom name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LocationSearchField(
                        controller: _addressController,
                        focusNode: _locationFocusNode,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Type an address, or tap for nearby places',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter or select an address.'
                            : null,
                        onManualEdit: () {
                          _latitude = null;
                          _longitude = null;
                        },
                        onCoordinates: (lat, lng) => setState(() {
                          _latitude = lat;
                          _longitude = lng;
                        }),
                        onArea: ({state, district, postcode}) => setState(
                          () => _applyGeocodedFields(
                            state: state,
                            district: district,
                            postcode: postcode,
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
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        // DropdownButtonFormField's `initialValue` (it's a
                        // FormField under the hood) is only applied on the
                        // widget's first build — programmatically changing
                        // `_state` later (e.g. from "Use Current Location") and
                        // calling setState does NOT make the dropdown re-display
                        // the new value on its own. Keying it on `_state` forces
                        // Flutter to treat a change as a brand-new widget
                        // instance, which re-seeds it correctly.
                        key: ValueKey(_state),
                        initialValue: _state,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                        items: MalaysiaGeocoder.states
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _state = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _districtController,
                        decoration: const InputDecoration(
                          labelText: 'District',
                          hintText: 'e.g. Petaling',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the district.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _postcodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Postcode (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Property Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: propertyTypeOptions.map((type) {
                          return SelectableChip(
                            label: type,
                            selected: _propertyType == type,
                            onTap: () => setState(() => _propertyType = type),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _floorsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of floors (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _estimatedValueController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Estimated property value (optional)',
                          prefixText: 'RM ',
                          border: OutlineInputBorder(),
                        ),
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
                                      : 'Add property'),
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
