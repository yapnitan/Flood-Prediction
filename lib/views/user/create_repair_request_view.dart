import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/nearby_locations.dart';
import '../../controllers/property_controller.dart';
import '../../controllers/repair_request_controller.dart';
import '../../models/assistance_field_spec.dart';
import '../../models/property.dart';
import '../../models/repair_request.dart';
import '../../services/location_service.dart';
import '../../services/property_service.dart';
import '../../services/repair_request_service.dart';
import '../../utils/responsive.dart';
import '../../utils/validators.dart';
import '../../widgets/add_new_dropdown_item.dart';
import '../../widgets/assistance_details_view.dart';
import '../../widgets/dynamic_assistance_fields.dart';
import '../../widgets/photo_preview.dart';
import '../../widgets/review_card.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/step_indicator.dart';
import 'property_form_view.dart';

class CreateRepairRequestView extends StatefulWidget {
  const CreateRepairRequestView({super.key});

  @override
  State<CreateRepairRequestView> createState() => _CreateRepairRequestState();
}

class _CreateRepairRequestState extends State<CreateRepairRequestView> {
  int _currentStep = 1;

  // Step 1 state
  final TextEditingController _locationNameController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();
  final LocationService _locationService = LocationService();
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isLocating = false;

  // Step 2 state
  String? selectedAssistanceType;
  final _detailsFormKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final Map<String, dynamic> _details = {};

  // Structural Repair: optional link to a saved property.
  final _propertyController = PropertyController(PropertyService());
  List<Property> _myProperties = [];
  Property? _selectedProperty;
  bool _isLoadingProperties = false;

  // Step 3 state
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _photos = [];
  final _repairRequestController = RepairRequestController(RepairRequestService());
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  final List<String> assistanceTypes = [
    'Structural Repair',
    'Temporary Shelter',
    'Food & Water Supply',
    'Medical Assistance',
    'Financial Aid',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactController.dispose();
    _locationNameController.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_currentStep == 1) {
      if (!_validateLocation()) return;
      setState(() => _currentStep = 2);
      return;
    }

    if (_currentStep == 2) {
      if (selectedAssistanceType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the type of assistance needed.')),
        );
        return;
      }
      if (!(_detailsFormKey.currentState?.validate() ?? false)) {
        return;
      }
      final missing = DynamicAssistanceFields.missingRequiredLabels(selectedAssistanceType!, _details);
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill in: ${missing.join(', ')}')),
        );
        return;
      }
      setState(() => _currentStep = 3);
      return;
    }

    if (_currentStep == 3) {
      setState(() => _currentStep = 4);
      return;
    }

    _submitRequest();
  }

  bool _validateLocation() {
    final name = _locationNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a location.')),
      );
      return false;
    }
    _selectedLatitude ??= 3.1390;
    _selectedLongitude ??= 101.6869;
    return true;
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    final details = await _locationService.getCurrentLocationDetails();
    if (!mounted) return;

    if (details == null) {
      setState(() => _isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to access your location. You can enter it manually.'),
        ),
      );
      return;
    }

    String readableAddress = details.address?.trim() ?? '';
    if (readableAddress.isEmpty) {
      readableAddress = 'Current location';
    }

    setState(() {
      _isLocating = false;
      _locationNameController.text = readableAddress;
      _selectedLatitude = details.position.latitude;
      _selectedLongitude = details.position.longitude;
    });
  }

  void _selectLocation(ReportLocation location) {
    _locationNameController.text = location.name;
    _selectedLatitude = location.latitude;
    _selectedLongitude = location.longitude;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  Future<void> _loadMyPropertiesIfNeeded() async {
    if (_myProperties.isNotEmpty || _isLoadingProperties) return;
    setState(() => _isLoadingProperties = true);
    final properties = await _propertyController.getMyProperties();
    if (!mounted) return;
    setState(() {
      _myProperties = properties;
      _isLoadingProperties = false;
    });
  }

  void _selectProperty(Property? property) {
    setState(() {
      _selectedProperty = property;
      if (property != null) {
        if (property.propertyType != null) _details['property_type'] = property.propertyType;
        if (property.floors != null) _details['number_of_floors'] = property.floors;
      }
    });
  }

  Future<void> _addNewProperty() async {
    final created = await Navigator.push<Property>(
      context,
      MaterialPageRoute(builder: (context) => PropertyFormView(controller: _propertyController)),
    );
    if (created == null || !mounted) return;
    setState(() => _myProperties = [created, ..._myProperties]);
    _selectProperty(created);
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting || _isSubmitted) return;

    setState(() => _isSubmitting = true);
    final description = _descriptionController.text.trim();
    final submitted = await _repairRequestController.submit(
      RepairRequest(
        locationName: _locationNameController.text.trim(),
        latitude: _selectedLatitude ?? 3.1390,
        longitude: _selectedLongitude ?? 101.6869,
        assistanceType: selectedAssistanceType!,
        priority: RepairRequest.suggestedPriority(selectedAssistanceType!),
        damageDescription: description.isEmpty ? null : description,
        contactNumber: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        details: _details,
      ),
      _photos,
    );
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (submitted) {
        _currentStep = 4;
        _isSubmitted = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submitted
              ? 'Your repair request has been submitted.'
              : 'Could not submit the request. Please try again.',
        ),
      ),
    );
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final selectedPhotos = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || selectedPhotos.isEmpty) return;
      setState(() => _photos.addAll(selectedPhotos));
      return;
    }

    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || photo == null) return;
    setState(() => _photos.add(photo));
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = context.screenWidth;
    final gridColumns = screenWidth >= 900 ? 4 : (screenWidth >= 600 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Property Damage'),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
            ),
            child: Column(
              children: [
                // ---- Step indicator ----
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: StepIndicator(
                    currentStep: _currentStep,
                    steps: const ["Location", "Damage Details", "Photos", "Submit"],
                  ),
                ),

                // ---- Scrollable form content ----
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsive(mobile: 20, tablet: 32, desktop: 40),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentStep == 1)
                          _buildLocationStep()
                        else if (_currentStep == 2)
                          _buildDetailsStep(gridColumns)
                        else if (_currentStep == 3)
                          _buildPhotosStep()
                        else if (_currentStep == 4)
                          _buildReviewStep(),
                      ],
                    ),
                  ),
                ),

                // ---- Navigation buttons ----
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.responsive(mobile: 20, tablet: 32, desktop: 40),
                    0,
                    context.responsive(mobile: 20, tablet: 32, desktop: 40),
                    20,
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 1 && !_isSubmitted) ...[
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => setState(() => _currentStep--),
                              child: const Text('Back'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmitting || _isSubmitted
                                ? null
                                : _goToNextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _isSubmitting
                                  ? 'Submitting...'
                                  : _isSubmitted
                                  ? 'Submitted'
                                  : _currentStep == 1
                                  ? 'Next'
                                  : _currentStep == 2
                                  ? 'Next: Photos'
                                  : _currentStep == 3
                                  ? 'Review Request'
                                  : 'Submit Request',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        const Text(
          'Where is the damage located?',
          style: TextStyle(color: Colors.grey),
        ),
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
                  children: [
                    ListTile(
                      leading: _isLocating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, color: Colors.blue),
                      title: const Text(
                        'Use Current Location',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Detect location using GPS'),
                      onTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        _useCurrentLocation();
                      },
                    ),
                    const Divider(height: 1),
                    ...options.map((location) {
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                        title: Text(location.name),
                        onTap: () => onSelected(location),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (value) {
              _locationNameController.value = controller.value;
              _selectedLatitude = null;
              _selectedLongitude = null;
            },
            decoration: InputDecoration(
              labelText: 'Search location',
              hintText: 'Tap to see nearby locations',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isLocating
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.blue),
                      tooltip: 'Use Current Location',
                      onPressed: _useCurrentLocation,
                    ),
              border: const OutlineInputBorder(
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
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDetailsStep(int gridColumns) {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type of Assistance Needed',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: gridColumns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: assistanceTypes
                .map(
                  (type) => SelectableChip(
                    label: type,
                    selected: selectedAssistanceType == type,
                    onTap: () {
                      setState(() => selectedAssistanceType = type);
                      if (type == 'Structural Repair') _loadMyPropertiesIfNeeded();
                    },
                  ),
                )
                .toList(),
          ),
          if (selectedAssistanceType != null) ...[
            const SizedBox(height: 24),
            Text(
              '${selectedAssistanceType!} Details',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'These details help admins and helpers respond appropriately.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            if (selectedAssistanceType == 'Structural Repair') ...[
              const Text('Linked property (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              _isLoadingProperties
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedProperty?.id.toString(),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      hint: const Text('Select a saved property'),
                      items: [
                        ..._myProperties.map((p) => DropdownMenuItem(value: p.id.toString(), child: Text(p.displayLabel))),
                        addNewMenuItem('Add new property'),
                      ],
                      onChanged: (value) {
                        if (value == kAddNewValue) {
                          _addNewProperty();
                          return;
                        }
                        _selectProperty(_myProperties.firstWhere((p) => p.id.toString() == value));
                      },
                    ),
              const SizedBox(height: 20),
            ],
            DynamicAssistanceFields(
              key: ValueKey('$selectedAssistanceType-${_selectedProperty?.id}'),
              assistanceType: selectedAssistanceType!,
              values: _details,
              onChanged: (key, value) => setState(() => _details[key] = value),
            ),
            if (descriptionLabelFor(selectedAssistanceType!) != null) ...[
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: isDescriptionRequiredFor(selectedAssistanceType!)
                      ? '${descriptionLabelFor(selectedAssistanceType!)} *'
                      : '${descriptionLabelFor(selectedAssistanceType!)} (optional)',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (!isDescriptionRequiredFor(selectedAssistanceType!)) return null;
                  return value == null || value.trim().isEmpty ? 'Enter a short description.' : null;
                },
              ),
              const SizedBox(height: 16),
            ],
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
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPhotosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        const Text(
          'Photos help helpers and admins assess the damage. They are optional.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _showPhotoSourcePicker,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Add photos'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 16),
        if (_photos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.image_outlined, size: 42, color: Colors.grey),
                SizedBox(height: 8),
                Text('No photos added yet'),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _photos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.responsive(mobile: 3, tablet: 4, desktop: 5),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) => PhotoPreview(
              photo: _photos[index],
              onRemove: () => setState(() => _photos.removeAt(index)),
            ),
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildReviewStep() {
    if (_isSubmitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text('Request submitted', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('A helper or admin will review your request soon.'),
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review Your Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Check the details below before submitting.'),
        const SizedBox(height: 20),
        ReviewCard(title: 'Location', value: _locationNameController.text.trim()),
        ReviewCard(title: 'Assistance type', value: selectedAssistanceType!),
        AssistanceDetailsView(assistanceType: selectedAssistanceType!, details: _details),
        if (_descriptionController.text.trim().isNotEmpty)
          ReviewCard(
            title: descriptionLabelFor(selectedAssistanceType!) ?? 'Description',
            value: _descriptionController.text.trim(),
          ),
        if (_contactController.text.trim().isNotEmpty)
          ReviewCard(title: 'Contact number', value: _contactController.text.trim()),
        ReviewCard(
          title: 'Photos',
          value: _photos.isEmpty ? 'No photos attached' : '${_photos.length} photo(s) attached',
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
