import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/nearby_locations.dart';
import '../../models/flood_report.dart';
import '../../services/flood_report_service.dart';
import '../../services/location_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/photo_preview.dart';
import '../../widgets/review_card.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/step_indicator.dart';

class SubmitReportPage extends StatefulWidget {
  const SubmitReportPage({super.key, this.onSubmissionComplete});

  final VoidCallback? onSubmissionComplete;

  @override
  State<SubmitReportPage> createState() => _SubmitReportState();
}

class _SubmitReportState extends State<SubmitReportPage> {
  int _currentStep = 1;

  // Step 1 state
  String? selectedFloodType;
  String? selectedWaterLevel;
  final TextEditingController _locationNameController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();
  final LocationService _locationService = LocationService();
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isLocating = false;

  // Step 2 state
  final _detailsFormKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _photos = [];
  final FloodReportService _floodReportService = FloodReportService();
  DateTime? _observedAt;
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  final List<String> floodTypes = [
    "Street Flooding",
    "River Overflow",
    "Drainage Issue",
    "Other",
  ];

  final List<Map<String, String>> waterLevels = [
    {"label": "Low", "sub": "(< 10 cm)"},
    {"label": "Medium", "sub": "(10 - 30 cm)"},
    {"label": "High", "sub": "(> 30 cm)"},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _dateTimeController.dispose();
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

    if (_currentStep == 2 &&
        !(_detailsFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_currentStep == 2) {
      setState(() => _currentStep = 3);
      return;
    }

    if (_currentStep == 3) {
      setState(() => _currentStep = 4);
      return;
    }

    _submitReport();
  }

  bool _validateLocation() {
    final name = _locationNameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please select or enter a location.');
      return false;
    }
    if (selectedFloodType == null) {
      _showSnack('Please select the type of flooding.');
      return false;
    }
    if (selectedWaterLevel == null) {
      _showSnack('Please select the water level.');
      return false;
    }
    _selectedLatitude ??= 3.1390;
    _selectedLongitude ??= 101.6869;
    return true;
  }

  /// Contact number is optional, but if entered must be 10 or 11 digits —
  /// no spaces, dashes, or country-code symbols.
  static final RegExp _contactNumberPattern = RegExp(r'^\d{10,11}$');

  String? _validateContactNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!_contactNumberPattern.hasMatch(trimmed)) {
      return 'Enter a 10 or 11 digit phone number.';
    }
    return null;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          content: Text(
            'Unable to access your location. You can enter it manually.',
          ),
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

  /// Flood reports describe recent, verifiable conditions — reports can't
  /// be dated in the future, and anything older than 2 days is stale
  /// enough that it belongs in historical records, not a live report.
  static const Duration _maxReportAge = Duration(days: 2);

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final earliestAllowed = now.subtract(_maxReportAge);
    final earliestAllowedDate = DateTime(
      earliestAllowed.year,
      earliestAllowed.month,
      earliestAllowed.day,
    );

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: earliestAllowedDate,
      lastDate: now,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // showDatePicker/showTimePicker are independent, so the calendar-day
    // restriction above doesn't stop a future *time* on today's date, nor
    // an earlier-than-allowed *time* on the oldest permitted day — recheck
    // the combined instant against the exact 2-day window.
    if (selected.isAfter(now)) {
      _showSnack('The observed date and time cannot be in the future.');
      return;
    }
    if (selected.isBefore(earliestAllowed)) {
      _showSnack('Please select a date and time within the past 2 days.');
      return;
    }

    setState(() {
      _observedAt = selected;
      _dateTimeController.text =
          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year} '
          '${time.format(context)}';
    });
  }

  Future<void> _submitReport() async {
    if (_isSubmitting || _isSubmitted) return;

    setState(() => _isSubmitting = true);
    final submitted = await _floodReportService.submit(
      FloodReport(
        locationName: _locationNameController.text.trim(),
        latitude: _selectedLatitude ?? 3.1390,
        longitude: _selectedLongitude ?? 101.6869,
        floodType: selectedFloodType!,
        waterLevel: selectedWaterLevel!,
        observedAt: _observedAt!,
        description: _descriptionController.text.trim(),
        contactNumber: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
      ),
      _photos,
    );
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (submitted) {
        _resetForm();
        _currentStep = 4;
        _isSubmitted = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submitted
              ? 'Your flood report has been submitted.'
              : 'Could not submit the report. Please try again.',
        ),
      ),
    );
  }

  void _resetForm() {
    _currentStep = 1;
    selectedFloodType = null;
    selectedWaterLevel = null;
    _observedAt = null;
    _descriptionController.clear();
    _dateTimeController.clear();
    _contactController.clear();
    _locationNameController.clear();
    _selectedLatitude = null;
    _selectedLongitude = null;
    _photos.clear();
    _isSubmitted = false;
  }

  void _completeSubmission() {
    setState(_resetForm);
    widget.onSubmissionComplete?.call();
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final selectedPhotos = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );
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
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(
                mobile: 700,
                tablet: 800,
                desktop: 900,
              ),
            ),
            child: Column(
              children: [
                // ---- Step indicator ----
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: StepIndicator(
                    currentStep: _currentStep,
                    steps: ["Location", "Details", "Photos", "Submit"],
                  ),
                ),

                // ---- Scrollable form content ----
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.responsive(
                        mobile: 20,
                        tablet: 32,
                        desktop: 40,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentStep == 1)
                          _buildLocationStep(gridColumns)
                        else if (_currentStep == 2)
                          _buildDetailsStep()
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
                                  ? 'Review Report'
                                  : 'Submit Report',
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

  Widget _buildLocationStep(int gridColumns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        RawAutocomplete<ReportLocation>(
          textEditingController: _locationNameController,
          focusNode: _locationFocusNode,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            return kNearbyLocations.where(
              (location) =>
                  query.isEmpty || location.name.toLowerCase().contains(query),
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
                constraints: const BoxConstraints(
                  maxHeight: 250,
                  maxWidth: 600,
                ),
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
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
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
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Colors.grey,
                        ),
                        title: Text(location.name),
                        onTap: () => onSelected(location),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) => TextField(
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
                          icon: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Type of Flooding',
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
          children: floodTypes
              .map(
                (type) => SelectableChip(
                  label: type,
                  selected: selectedFloodType == type,
                  onTap: () => setState(() => selectedFloodType = type),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Water Level (Approx.)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          children: waterLevels
              .map(
                (level) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SelectableChip(
                      label: level['label']!,
                      sublabel: level['sub'],
                      selected: selectedWaterLevel == level['label'],
                      onTap: () =>
                          setState(() => selectedWaterLevel = level['label']),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Flood Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us when the flooding occurred and any useful information.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _dateTimeController,
            readOnly: true,
            onTap: _selectDateTime,
            decoration: const InputDecoration(
              labelText: 'Date and time observed',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.isEmpty
                ? 'Select when you observed the flooding.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText:
                  'Describe the flooding, road conditions, or immediate hazards.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a short description.'
                : null,
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
            validator: _validateContactNumber,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPhotosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Photos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Photos help responders verify the report. They are optional.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _showPhotoSourcePicker,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Add photos'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
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
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 72,
              ),
              const SizedBox(height: 16),
              const Text(
                'Report submitted',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Thank you for helping keep your community informed.'),
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton(
                  onPressed: _completeSubmission,
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
        const Text(
          'Review Your Report',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Check the details below before submitting.'),
        const SizedBox(height: 20),
        ReviewCard(
          title: 'Location',
          value: _locationNameController.text.trim(),
        ),
        ReviewCard(title: 'Flood type', value: selectedFloodType!),
        ReviewCard(title: 'Water level', value: selectedWaterLevel!),
        ReviewCard(title: 'Observed', value: _dateTimeController.text),
        ReviewCard(
          title: 'Description',
          value: _descriptionController.text.trim(),
        ),
        if (_contactController.text.trim().isNotEmpty)
          ReviewCard(
            title: 'Contact number',
            value: _contactController.text.trim(),
          ),
        ReviewCard(
          title: 'Photos',
          value: _photos.isEmpty
              ? 'No photos attached'
              : '${_photos.length} photo(s) attached',
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
