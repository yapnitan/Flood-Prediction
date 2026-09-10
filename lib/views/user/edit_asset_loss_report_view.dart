import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../models/asset_loss_report.dart';
import '../../services/asset_loss_report_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/responsive.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/photo_preview.dart';
import '../../widgets/selectable_chip.dart';

class EditAssetLossReportView extends StatefulWidget {
  const EditAssetLossReportView({super.key, required this.report});

  final AssetLossReport report;

  @override
  State<EditAssetLossReportView> createState() =>
      _EditAssetLossReportViewState();
}

class _EditAssetLossReportViewState extends State<EditAssetLossReportView> {
  final _controller = AssetLossReportController(AssetLossReportService());
  final _formKey = GlobalKey<FormState>();

  late String _category;
  late String? _condition;
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _quantityController = TextEditingController();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _imagePicker = ImagePicker();
  final List<XFile> _newPhotos = [];
  late List<String> _existingPhotoPaths;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    _category = assetCategories.contains(r.assetCategory)
        ? r.assetCategory
        : assetCategories.first;
    _condition = r.condition;
    _nameController.text = r.assetName;
    _quantityController.text = '${r.quantity}';
    _valueController.text = formatAmount(r.estimatedValuePerItem);
    _descriptionController.text = r.description ?? '';
    _existingPhotoPaths = List<String>.from(r.photoPaths);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _quantityController.dispose();
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showSnack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final selected = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || selected.isEmpty) return;
      setState(() => _newPhotos.addAll(selected));
      return;
    }
    final photo =
        await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (!mounted || photo == null) return;
    setState(() => _newPhotos.add(photo));
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhotos(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhotos(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_condition == null) {
      _showSnack("Please select the asset's condition.");
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);

    final r = widget.report;
    final ok = await _controller.updateReport(
      r.id!,
      AssetLossReport(
        propertyId: r.propertyId,
        floodIncidentId: r.floodIncidentId,
        assetCategory: _category,
        assetName: _nameController.text.trim(),
        condition: _condition!,
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        estimatedValuePerItem:
            CurrencyInputFormatter.parse(_valueController.text) ?? 0,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      ),
      _existingPhotoPaths,
      _newPhotos,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      _showSnack('Report updated.');
      Navigator.of(context).pop(true);
    } else {
      _showSnack('Could not save your changes. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final examples = assetCategoryExamples[_category] ?? const [];

    return AbsorbPointer(
      absorbing: _isSaving,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Edit Asset Loss Report'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsive(mobile: 20, tablet: 32, desktop: 40),
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.responsive(mobile: 600, tablet: 640),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Asset Category',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: assetCategories
                            .map((c) => SelectableChip(
                                  label: c,
                                  selected: _category == c,
                                  onTap: () => setState(() => _category = c),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      RawAutocomplete<String>(
                        key: ValueKey(_category),
                        textEditingController: _nameController,
                        focusNode: _nameFocusNode,
                        optionsBuilder: (value) {
                          final q = value.text.trim().toLowerCase();
                          if (q.isEmpty) return examples;
                          return examples
                              .where((e) => e.toLowerCase().contains(q));
                        },
                        onSelected: (value) => _nameController.text = value,
                        optionsViewBuilder: (context, onSelected, options) => Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(10),
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxHeight: 250, maxWidth: 600),
                              child: ListView(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                children: options
                                    .map((e) => ListTile(
                                        title: Text(e),
                                        onTap: () => onSelected(e)))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                        fieldViewBuilder:
                            (context, controller, focusNode, onSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Asset name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
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
                                  decimal: true),
                              inputFormatters: const [CurrencyInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Value per item',
                                prefixText: 'RM ',
                                border: OutlineInputBorder(),
                              ),
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
                      const SizedBox(height: 20),
                      const Text('Condition',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: assetConditions
                            .map((c) => SelectableChip(
                                  label: assetConditionLabels[c]!,
                                  selected: _condition == c,
                                  onTap: () => setState(() => _condition = c),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
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
                      const Text('Evidence Photos',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text(
                        'Existing photos are kept. Anything you add is appended.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      if (_existingPhotoPaths.isNotEmpty) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _existingPhotoPaths.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: context.responsive(
                                mobile: 3, tablet: 4, desktop: 5),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemBuilder: (context, index) => NetworkPhotoThumbnail(
                            storagePath: _existingPhotoPaths[index],
                            urlResolver: _controller.getSignedPhotoUrl,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: _showPhotoSourcePicker,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Add photos'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                      ),
                      if (_newPhotos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _newPhotos.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: context.responsive(
                                mobile: 3, tablet: 4, desktop: 5),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemBuilder: (context, index) => PhotoPreview(
                            photo: _newPhotos[index],
                            onRemove: () =>
                                setState(() => _newPhotos.removeAt(index)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _isSaving ? 'Saving...' : 'Save changes',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
