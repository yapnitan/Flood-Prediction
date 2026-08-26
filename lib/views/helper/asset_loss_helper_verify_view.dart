import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../utils/maps_launcher.dart';
import '../../utils/responsive.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/photo_preview.dart';
import '../../widgets/review_card.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/status_badge.dart';

/// Helper's on-site verification form for one district-matched asset loss
/// report (Task/asset report §29). Supports partial verification (§31) —
/// the helper's verified quantity/value can differ from what the resident
/// reported; the admin makes the final approval call afterward.
class AssetLossHelperVerifyView extends StatefulWidget {
  const AssetLossHelperVerifyView({super.key, required this.data, required this.controller});

  final Map<String, dynamic> data;
  final AssetLossReportController controller;

  @override
  State<AssetLossHelperVerifyView> createState() => _AssetLossHelperVerifyViewState();
}

class _AssetLossHelperVerifyViewState extends State<AssetLossHelperVerifyView> {
  late final TextEditingController _quantityController;
  late final TextEditingController _valueController;
  final TextEditingController _notesController = TextEditingController();
  String? _condition;
  String? _result;
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _photos = [];
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '${widget.data['quantity']}');
    _valueController = TextEditingController(text: '${widget.data['estimated_value_per_item']}');
    _condition = widget.data['condition'] as String?;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final selected = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || selected.isEmpty) return;
      setState(() => _photos.addAll(selected));
      return;
    }
    final photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
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

  Future<void> _submit() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    final value = double.tryParse(_valueController.text.trim());
    if (quantity == null || quantity <= 0 || value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid verified quantity and value.')),
      );
      return;
    }
    if (_condition == null || _result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the observed condition and verification result.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await widget.controller.submitVerification(
      reportId: widget.data['id'] as String,
      reportOwnerId: widget.data['user_id'] as String,
      verifiedQuantity: quantity,
      verifiedValuePerItem: value,
      verifiedCondition: _condition!,
      verificationResult: _result!,
      verificationNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      verificationPhotos: _photos,
    );
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _isSubmitted = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification submitted for admin review.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final property = data['property'] as Map<String, dynamic>?;
    final photoPaths = (data['photo_paths'] as List?)?.cast<String>() ?? const [];
    final estimatedTotal = (data['estimated_total_loss'] as num?)?.toDouble() ?? 0;
    final lat = (property?['lat'] as num?)?.toDouble();
    final lng = (property?['lng'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Verify Asset Loss'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${data['asset_category']} — ${data['asset_name']}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      StatusBadge(status: data['status'] as String? ?? 'pending_review'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (property != null)
                    ReviewCard(
                      title: 'Address',
                      value: '${property['label'] ?? ''} ${property['address'] ?? ''}\n'
                          '${property['district'] ?? ''}, ${property['state'] ?? ''}'.trim(),
                    ),
                  if (lat != null && lng != null) ...[
                    MiniMap(markers: [MapMarkerSpec(point: LatLng(lat, lng), color: Colors.red)]),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => openDirections(context, latitude: lat, longitude: lng),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Get directions'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ReviewCard(
                    title: 'Reported condition',
                    value: assetConditionLabels[data['condition']] ?? '${data['condition']}',
                  ),
                  ReviewCard(title: 'Reported quantity', value: '${data['quantity']}'),
                  ReviewCard(
                    title: 'Reported value per item',
                    value: 'RM ${(data['estimated_value_per_item'] as num).toStringAsFixed(2)}',
                  ),
                  ReviewCard(title: 'Potential Asset Loss', value: 'RM ${estimatedTotal.toStringAsFixed(2)}'),
                  if ((data['description'] as String?)?.trim().isNotEmpty ?? false)
                    ReviewCard(title: 'Description', value: data['description'] as String),

                  const SizedBox(height: 12),
                  const Text('Resident\'s Evidence Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  if (photoPaths.isEmpty)
                    const Text('No photos attached', style: TextStyle(color: Colors.grey))
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: photoPaths.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) => NetworkPhotoThumbnail(
                        storagePath: photoPaths[index],
                        urlResolver: widget.controller.getSignedPhotoUrl,
                      ),
                    ),

                  if (_isSubmitted) ...[
                    const Divider(height: 32),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Verification submitted — awaiting admin review.', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ] else ...[
                    const Divider(height: 32),
                    const Text('Your Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Verified quantity', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _valueController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Verified value/item',
                              prefixText: 'RM ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Observed Condition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: assetConditions.map((c) {
                        return SelectableChip(
                          label: assetConditionLabels[c]!,
                          selected: _condition == c,
                          onTap: () => setState(() => _condition = c),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Verification Result', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: verificationResults.map((r) {
                        return SelectableChip(
                          label: verificationResultLabels[r]!,
                          selected: _result == r,
                          onTap: () => setState(() => _result = r),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Verification notes (optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showPhotoSourcePicker,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add verification photos'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                    if (_photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
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
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        child: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit Verification',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
