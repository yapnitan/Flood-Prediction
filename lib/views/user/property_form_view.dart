import 'package:flutter/material.dart';
import '../../constants/nearby_locations.dart';
import '../../controllers/property_controller.dart';
import '../../models/assistance_field_spec.dart';
import '../../models/property.dart';
import '../../services/location_service.dart';
import '../../widgets/selectable_chip.dart';

class PropertyFormView extends StatefulWidget {
  const PropertyFormView({super.key, required this.controller});

  final PropertyController controller;

  @override
  State<PropertyFormView> createState() => _PropertyFormViewState();
}

class _PropertyFormViewState extends State<PropertyFormView> {
  final _formKey = GlobalKey<FormState>();
  final LocationService _locationService = LocationService();

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _floorsController = TextEditingController();
  final TextEditingController _estimatedValueController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();

  String? _propertyType;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _addressController.dispose();
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
    });
  }

  void _selectLocation(ReportLocation location) {
    _addressController.text = location.name;
    _latitude = location.latitude;
    _longitude = location.longitude;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a location for this property.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final created = await widget.controller.createProperty(Property(
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      lat: _latitude!,
      lng: _longitude!,
      propertyType: _propertyType,
      floors: int.tryParse(_floorsController.text.trim()),
      estimatedValue: double.tryParse(_estimatedValueController.text.trim()),
    ));

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (created != null) {
      Navigator.of(context).pop(created);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the property. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Add Property'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                RawAutocomplete<ReportLocation>(
                  textEditingController: _addressController,
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
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Enter or select an address.' : null,
                    decoration: const InputDecoration(
                      labelText: 'Address',
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
                ],
                const SizedBox(height: 24),
                const Text('Property Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isSaving ? 'Saving...' : 'Add property',
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
