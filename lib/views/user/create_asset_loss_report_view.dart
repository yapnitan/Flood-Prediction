import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../controllers/flood_incident_controller.dart';
import '../../controllers/property_controller.dart';
import '../../models/asset_loss_report.dart';
import '../../models/flood_incident.dart';
import '../../models/property.dart';
import '../../services/asset_ai_service.dart';
import '../../services/asset_loss_report_service.dart';
import '../../services/flood_incident_service.dart';
import '../../services/property_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/responsive.dart';
import '../../widgets/photo_preview.dart';
import '../../widgets/review_card.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/step_indicator.dart';
import 'property_form_view.dart';

class _PendingAsset {
  const _PendingAsset({
    required this.category,
    required this.assetName,
    required this.condition,
    required this.quantity,
    required this.valuePerItem,
    this.description,
    required this.photos,
  });

  final String category;
  final String assetName;
  final String condition;
  final int quantity;
  final double valuePerItem;
  final String? description;
  final List<XFile> photos;

  double get totalLoss => quantity * valuePerItem;
}

class CreateAssetLossReportView extends StatefulWidget {
  const CreateAssetLossReportView({super.key});

  @override
  State<CreateAssetLossReportView> createState() =>
      _CreateAssetLossReportViewState();
}

class _CreateAssetLossReportViewState extends State<CreateAssetLossReportView> {
  int _currentStep = 1;

  final _propertyController = PropertyController(PropertyService());
  final _floodIncidentController = FloodIncidentController(
    FloodIncidentService(),
  );
  final _reportController = AssetLossReportController(AssetLossReportService());

  bool _isLoadingProperties = true;
  List<Property> _myProperties = [];
  Property? _selectedProperty;

  List<FloodIncident> _activeIncidents = [];
  FloodIncident? _selectedIncident;

  final List<_PendingAsset> _pendingAssets = [];

  String? _selectedCategory;
  final TextEditingController _assetNameController = TextEditingController();
  final FocusNode _assetNameFocusNode = FocusNode();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _valueController = TextEditingController();
  String? _selectedCondition;
  final _detailsFormKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _photos = [];
  final AssetAiService _aiService = AssetAiService();

  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _isAnalyzing = false;
  bool _allowPop = false;

  int _submittedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAddressesAndIncidents();
  }

  @override
  void dispose() {
    _assetNameController.dispose();
    _assetNameFocusNode.dispose();
    _quantityController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadAddressesAndIncidents() async {
    final properties = await _propertyController.getMyProperties();
    final incidents = await _floodIncidentController.getActive();
    if (!mounted) return;
    setState(() {
      _myProperties = properties;
      _selectedProperty = properties.isNotEmpty ? properties.first : null;
      _activeIncidents = incidents;
      _isLoadingProperties = false;
    });
  }

  Future<void> _addAddress() async {
    final created = await Navigator.push<Property>(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFormView(controller: _propertyController),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _myProperties = [created, ..._myProperties];
      _selectedProperty = created;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToNextStep() {
    if (_currentStep == 1) {
      if (_selectedProperty == null) {
        _showSnack('Please select the address where the asset loss occurred.');
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    if (_currentStep == 2) {
      if (_selectedCategory == null) {
        _showSnack('Please select an asset category.');
        return;
      }
      if (_selectedCondition == null) {
        _showSnack('Please select the asset\'s condition.');
        return;
      }
      if (!(_detailsFormKey.currentState?.validate() ?? false)) return;
      setState(() => _currentStep = 3);
      return;
    }
  }

  double get _estimatedTotalLoss {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final value = CurrencyInputFormatter.parse(_valueController.text) ?? 0;
    return quantity * value;
  }

  _PendingAsset _captureCurrentAsset() {
    return _PendingAsset(
      category: _selectedCategory ?? assetCategories.first,
      assetName: _assetNameController.text.trim(),
      condition: _selectedCondition ?? assetConditions.first,
      quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
      valuePerItem: CurrencyInputFormatter.parse(_valueController.text) ?? 0,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      photos: List<XFile>.from(_photos),
    );
  }

  List<_PendingAsset> get _allAssets => [..._pendingAssets, _captureCurrentAsset()];

  void _resetCurrentAssetFields() {
    _selectedCategory = null;
    _assetNameController.clear();
    _quantityController.text = '1';
    _valueController.clear();
    _selectedCondition = null;
    _descriptionController.clear();
    _photos.clear();
  }

  void _addAnotherAsset() {
    setState(() {
      _pendingAssets.add(_captureCurrentAsset());
      _resetCurrentAssetFields();
      _currentStep = 2;
    });
    _showSnack('Asset added — enter another, or review and submit when done.');
  }

  void _proceedToReview() {
    setState(() => _currentStep = 4);
  }

  void _removePendingAsset(int index) {
    setState(() => _pendingAssets.removeAt(index));
  }

  Future<void> _submitAllReports() async {
    if (_isSubmitting || _isSubmitted) return;
    final assets = _allAssets;
    if (assets.isEmpty) return;
    setState(() => _isSubmitting = true);

    var allSucceeded = true;
    for (final asset in assets) {
      final submitted = await _reportController.submit(
        AssetLossReport(
          propertyId: _selectedProperty!.id!,
          floodIncidentId: _selectedIncident?.id,
          assetCategory: asset.category,
          assetName: asset.assetName,
          condition: asset.condition,
          quantity: asset.quantity,
          estimatedValuePerItem: asset.valuePerItem,
          description: asset.description,
        ),
        asset.photos,
      );
      if (!submitted) allSucceeded = false;
    }
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (allSucceeded) {
        _isSubmitted = true;
        _submittedCount = assets.length;
      }
    });

    _showSnack(
      allSucceeded
          ? (assets.length > 1
                ? 'Your ${assets.length} asset loss reports have been submitted.'
                : 'Your asset loss report has been submitted.')
          : 'Some reports could not be submitted. Please try again.',
    );
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final selected = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || selected.isEmpty) return;
      setState(() => _photos.addAll(selected));
      return;
    }
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!mounted || photo == null) return;
    setState(() => _photos.add(photo));
  }

  void _showAiSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Take or choose a photo of the damaged item — Gemini will fill '
                'in the category, name, condition and quantity. You enter the '
                'loss amount.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _analyzeWithAi(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _analyzeWithAi(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeWithAi(ImageSource source) async {
    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (!mounted || photo == null) return;
    setState(() {
      _photos.add(photo);
      _isAnalyzing = true;
    });

    final suggestion = await _aiService.analysePhotos([photo]);
    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    if (suggestion == null) {
      _showSnack(
        'Could not analyse the photo — please fill in the details manually.',
      );
      return;
    }

    setState(() {
      final s = suggestion;
      if (s.category != null) _selectedCategory = s.category;
      if ((s.assetName ?? '').isNotEmpty) _assetNameController.text = s.assetName!;
      if (s.condition != null) _selectedCondition = s.condition;
      if ((s.quantity ?? 0) > 0) _quantityController.text = '${s.quantity}';
      final desc = suggestion.description;
      if (desc != null &&
          desc.isNotEmpty &&
          _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = desc;
      }
    });

    _showSnack(
      suggestion.note != null
          ? 'Gemini filled in the details — ${suggestion.note}'
          : 'Gemini filled in the details — check them and enter the loss amount.',
    );
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

  Future<void> _confirmDiscardAndLeave() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        title: const Text('Discard report?'),
        content: const Text(
          'Your input in this form will be lost if you go back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Report Asset Loss'), centerTitle: true),
      body: SafeArea(
        child: _isLoadingProperties
            ? const Center(child: CircularProgressIndicator())
            : _myProperties.isEmpty
            ? _buildNoAddressGate()
            : _buildWizard(),
      ),
    );

    return PopScope(
      canPop: _allowPop || _isSubmitted,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _confirmDiscardAndLeave();
      },
      child: scaffold,
    );
  }

  Widget _buildNoAddressGate() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'You need to add an address before reporting asset loss.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Save the address where the loss occurred, then come back here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _addAddress,
                icon: const Icon(
                  Icons.add_location_alt_outlined,
                  color: Colors.white,
                ),
                label: const Text(
                  'Add Address',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _footerButtonLabel() {
    if (_isSubmitting) return 'Submitting...';
    if (_isSubmitted) return 'Submitted';
    switch (_currentStep) {
      case 1:
        return 'Next';
      case 2:
        return 'Next: Photos';
      case 3:
        return 'Review All (${_pendingAssets.length + 1})';
      case 4:
        return _allAssets.length > 1
            ? 'Submit ${_allAssets.length} Reports'
            : 'Submit Report';
      default:
        return 'Next';
    }
  }

  VoidCallback? _footerButtonAction() {
    if (_isSubmitting || _isSubmitted) return null;
    switch (_currentStep) {
      case 3:
        return _proceedToReview;
      case 4:
        return _submitAllReports;
      default:
        return _goToNextStep;
    }
  }

  Widget _buildWizard() {
    final keyboardVisible = context.isKeyboardVisible;
    final horizontalPadding = context.responsive(
      mobile: 20.0,
      tablet: 32.0,
      desktop: 40.0,
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
        ),
        child: CustomScrollView(

          slivers: [
            if (!keyboardVisible && !_isSubmitted)
              SliverAppBar(
                key: const ValueKey('asset-loss-step-indicator'),
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                elevation: 0,
                toolbarHeight: 0,
                automaticallyImplyLeading: false,
                floating: true,
                snap: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(78),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: StepIndicator(
                      currentStep: _currentStep,
                      steps: const ['Address', 'Asset', 'Photos', 'Submit'],
                    ),
                  ),
                ),
              ),
            SliverPadding(
              key: const ValueKey('asset-loss-form-content'),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentStep == 1) _buildAddressStep(),
                    if (_currentStep == 2) _buildAssetDetailsStep(),
                    if (_currentStep == 3) _buildPhotosStep(),
                    if (_currentStep == 4) _buildReviewStep(),
                  ],
                ),
              ),
            ),
            if (!keyboardVisible && !_isSubmitted)
              SliverPadding(
                key: const ValueKey('asset-loss-nav-buttons'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  20,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentStep == 3) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : _addAnotherAsset,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Another Asset'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          if (_currentStep > 1) ...[
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _currentStep--),
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
                                onPressed: _footerButtonAction(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _footerButtonLabel(),
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
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select affected address',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Which of your saved addresses was affected by the flood?',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ..._myProperties.map(
          (property) => RadioListTile<int>(
            value: property.id!,
            // ignore: deprecated_member_use
            groupValue: _selectedProperty?.id,
            // ignore: deprecated_member_use
            onChanged: (value) => setState(
              () => _selectedProperty = _myProperties.firstWhere(
                (p) => p.id == value,
              ),
            ),
            title: Text(property.displayLabel),
            subtitle: property.district != null
                ? Text('${property.district}, ${property.state}')
                : null,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addAddress,
          icon: const Icon(Icons.add),
          label: const Text('Add another address'),
        ),
        if (_activeIncidents.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Flood incident (optional)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedIncident?.id,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            hint: const Text('Not linked to a specific incident'),
            isExpanded: true,
            items: _activeIncidents
                .map(
                  (incident) => DropdownMenuItem(
                    value: incident.id,
                    child: Text(incident.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(
              () => _selectedIncident = _activeIncidents.firstWhere(
                (i) => i.id == value,
              ),
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildAssetDetailsStep() {
    final examples = assetCategoryExamples[_selectedCategory] ?? const [];
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingAssets.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_pendingAssets.length} asset(s) already added to this report.',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_aiService.isConfigured) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.deepPurple.shade400,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Fill this in from a photo',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Snap the damaged item and Gemini identifies the category, '
                    'name, condition and quantity. You enter the loss amount, '
                    'and can edit everything afterwards.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isAnalyzing ? null : _showAiSourcePicker,
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined, size: 18),
                      label: Text(
                        _isAnalyzing ? 'Analysing photo…' : 'Analyse a photo',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: BorderSide(color: Colors.deepPurple.shade200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Asset Category',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: assetCategories.map((category) {
              return SelectableChip(
                label: category,
                selected: _selectedCategory == category,
                onTap: () {
                  setState(() => _selectedCategory = category);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _assetNameController.clear();
                  });
                },
              );
            }).toList(),
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 20),
            RawAutocomplete<String>(
              key: ValueKey(_selectedCategory),
              textEditingController: _assetNameController,
              focusNode: _assetNameFocusNode,
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                if (query.isEmpty) return examples;
                return examples.where((e) => e.toLowerCase().contains(query));
              },
              onSelected: (value) => _assetNameController.text = value,
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
                      children: options.map((example) {
                        return ListTile(
                          title: Text(example),
                          onTap: () => onSelected(example),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Asset name',
                    hintText: 'e.g. Refrigerator',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the asset name.'
                      : null,
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final n = int.tryParse(value?.trim() ?? '');
                      return (n == null || n <= 0)
                          ? 'Enter a valid quantity.'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [CurrencyInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Value per item',
                      prefixText: 'RM ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final n = CurrencyInputFormatter.parse(value);
                      return (n == null || n < 0)
                          ? 'Enter a valid value.'
                          : null;
                    },
                  ),
                ),
              ],
            ),
            if (_quantityController.text.trim().isNotEmpty &&
                _valueController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated asset loss: ${formatRinggit(_estimatedTotalLoss)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Condition',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assetConditions.map((condition) {
                return SelectableChip(
                  label: assetConditionLabels[condition]!,
                  selected: _selectedCondition == condition,
                  onTap: () => setState(() => _selectedCondition = condition),
                );
              }).toList(),
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
        const Text(
          'Description',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Additional details (optional)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Evidence Photos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Photos help helpers and admins verify the loss.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
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
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.responsive(
                mobile: 3,
                tablet: 4,
                desktop: 5,
              ),
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
      return _buildSubmittedScreen();
    }

    final assets = _allAssets;
    final grandTotal = assets.fold<double>(0, (sum, a) => sum + a.totalLoss);

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
        ReviewCard(title: 'Address', value: _selectedProperty!.displayLabel),
        if (_selectedIncident != null)
          ReviewCard(title: 'Flood incident', value: _selectedIncident!.name),
        const SizedBox(height: 8),
        Text(
          '${assets.length} asset${assets.length == 1 ? '' : 's'} reported',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        ...assets.asMap().entries.map((entry) {

          final isQueued = entry.key < _pendingAssets.length;
          return _PendingAssetCard(
            asset: entry.value,
            onRemove:
                isQueued ? () => _removePendingAsset(entry.key) : null,
          );
        }),
        const SizedBox(height: 12),
        ReviewCard(
          title: 'Total Potential Asset Loss',
          value: formatRinggit(grandTotal),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSubmittedScreen() {
    final many = _submittedCount > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 56, 8, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: Colors.green.shade600, size: 52),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            many ? '$_submittedCount reports submitted' : 'Report submitted',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            many
                ? 'Your $_submittedCount asset loss reports have been sent. An admin '
                    'or assigned helper will review them soon.'
                : 'Your asset loss report has been sent. An admin or assigned '
                    'helper will review it soon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingAssetCard extends StatelessWidget {
  const _PendingAssetCard({required this.asset, this.onRemove});

  final _PendingAsset asset;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${asset.category} — ${asset.assetName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove',
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${assetConditionLabels[asset.condition]} · Qty ${asset.quantity} · '
            '${formatRinggit(asset.valuePerItem)} each',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatRinggit(asset.totalLoss)}'
            '${asset.photos.isNotEmpty ? ' · ${asset.photos.length} photo(s)' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
