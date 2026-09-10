import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../utils/currency_input.dart';
import '../../utils/maps_launcher.dart';
import '../../utils/responsive.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/photo_gallery_viewer.dart';
import '../../widgets/photo_preview.dart';
import '../../widgets/review_card.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/status_badge.dart';

/// Helper's on-site verification form for one district-matched asset loss
/// report (Task/asset report §29). Supports partial verification (§31) —
/// the helper's verified quantity/value can differ from what the resident
/// reported; the admin makes the final approval call afterward.
class AssetLossHelperVerifyView extends StatefulWidget {
  const AssetLossHelperVerifyView({
    super.key,
    required this.data,
    required this.controller,
  });

  final Map<String, dynamic> data;
  final AssetLossReportController controller;

  @override
  State<AssetLossHelperVerifyView> createState() =>
      _AssetLossHelperVerifyViewState();
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

  static const _maxPhotos = 3;

  String get _status => widget.data['status'] as String? ?? 'pending_review';

  /// A helper may only verify a report that is still pending review and has
  /// not been verified by anyone yet — matches migration 0036/0038's RLS.
  bool get _alreadyVerified =>
      (widget.data['verification_result'] as String?) != null ||
      _status == 'helper_verified';
  bool get _reportSettled => _status == 'verified' || _status == 'rejected';
  bool get _canVerify => !_alreadyVerified && !_reportSettled;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: '${widget.data['quantity']}',
    );
    _valueController = TextEditingController(
      text: formatAmount(
        (widget.data['estimated_value_per_item'] as num?) ?? 0,
      ),
    );
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
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can attach at most $_maxPhotos photos.')),
      );
      return;
    }

    if (source == ImageSource.gallery) {
      final selected = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (!mounted || selected.isEmpty) return;
      final toAdd = selected.take(remaining).toList();
      setState(() => _photos.addAll(toAdd));
      if (toAdd.length < selected.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only added ${toAdd.length} photo(s) — the limit is $_maxPhotos photos.',
            ),
          ),
        );
      }
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
    if (_photos.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can attach at most $_maxPhotos photos.')),
      );
      return;
    }
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
    if (_isSubmitting || !_canVerify) return;

    final quantity = int.tryParse(_quantityController.text.trim());
    final value = CurrencyInputFormatter.parse(_valueController.text);
    if (quantity == null || quantity <= 0 || value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid verified quantity and value.'),
        ),
      );
      return;
    }
    if (_condition == null || _result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select the observed condition and verification result.',
          ),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);
    try {
      await widget.controller.submitVerification(
        reportId: widget.data['id'] as String,
        reportOwnerId: widget.data['user_id'] as String,
        verifiedQuantity: quantity,
        verifiedValuePerItem: value,
        verifiedCondition: _condition!,
        verificationResult: _result!,
        verificationNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        verificationPhotos: _photos,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      debugPrint('AssetLossHelperVerifyView._submit error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit the verification: $error')),
      );
      return;
    }
    if (!mounted) return;
    // Back to the helper dashboard — it shows the confirmation snackbar and
    // refreshes the list so this report moves to the "Reviewed" section.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final property = data['property'] as Map<String, dynamic>?;
    final photoPaths =
        (data['photo_paths'] as List?)?.cast<String>() ?? const [];
    final estimatedTotal =
        (data['estimated_total_loss'] as num?)?.toDouble() ?? 0;
    final lat = (property?['lat'] as num?)?.toDouble();
    final lng = (property?['lng'] as num?)?.toDouble();

    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Verify Asset Loss'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${data['asset_category']} — ${data['asset_name']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusBadge(
                          status: data['status'] as String? ?? 'pending_review',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (property != null)
                      ReviewCard(
                        title: 'Address',
                        value:
                            '${property['label'] ?? ''} ${property['address'] ?? ''}\n'
                                    '${property['district'] ?? ''}, ${property['state'] ?? ''}'
                                .trim(),
                      ),
                    if (lat != null && lng != null) ...[
                      MiniMap(
                        markers: [
                          MapMarkerSpec(
                            point: LatLng(lat, lng),
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => openDirections(
                          context,
                          latitude: lat,
                          longitude: lng,
                        ),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Get directions'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ReviewCard(
                      title: 'Reported condition',
                      value:
                          assetConditionLabels[data['condition']] ??
                          '${data['condition']}',
                    ),
                    ReviewCard(
                      title: 'Reported quantity',
                      value: '${data['quantity']}',
                    ),
                    ReviewCard(
                      title: 'Reported value per item',
                      value: formatRinggit(
                        (data['estimated_value_per_item'] as num?) ?? 0,
                      ),
                    ),
                    ReviewCard(
                      title: 'Potential Asset Loss',
                      value: formatRinggit(estimatedTotal),
                    ),
                    if ((data['description'] as String?)?.trim().isNotEmpty ??
                        false)
                      ReviewCard(
                        title: 'Description',
                        value: data['description'] as String,
                      ),

                    const SizedBox(height: 12),
                    const Text(
                      'Resident\'s Evidence Photos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (photoPaths.isEmpty)
                      const Text(
                        'No photos attached',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      _EvidencePhotoGrid(
                        paths: photoPaths,
                        controller: widget.controller,
                      ),

                    if (!_canVerify) ...[
                      const Divider(height: 32),
                      _ClosedNotice(
                        settled: _reportSettled,
                        status: data['status'] as String? ?? 'pending_review',
                      ),
                      if (_alreadyVerified) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Recorded Verification',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ReviewCard(
                          title: 'Result',
                          value:
                              verificationResultLabels[data['verification_result']] ??
                              '${data['verification_result']}',
                        ),
                        if (data['verified_quantity'] != null)
                          ReviewCard(
                            title: 'Verified quantity',
                            value: '${data['verified_quantity']}',
                          ),
                        if (data['verified_value_per_item'] != null)
                          ReviewCard(
                            title: 'Verified value per item',
                            value: formatRinggit(
                              (data['verified_value_per_item'] as num?) ?? 0,
                            ),
                          ),
                        if (data['verified_condition'] != null)
                          ReviewCard(
                            title: 'Observed condition',
                            value:
                                assetConditionLabels[data['verified_condition']] ??
                                '${data['verified_condition']}',
                          ),
                        if ((data['verification_notes'] as String?)
                                ?.trim()
                                .isNotEmpty ??
                            false)
                          ReviewCard(
                            title: 'Notes',
                            value: data['verification_notes'] as String,
                          ),
                      ],
                    ] else ...[
                      const Divider(height: 32),
                      const Text(
                        'Your Verification',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Verified quantity',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _valueController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: const [CurrencyInputFormatter()],
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
                      const Text(
                        'Observed Condition',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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
                      const Text(
                        'Verification Result',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Up to $_maxPhotos photos.',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (_photos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _photos.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemBuilder: (context, index) => PhotoPreview(
                            photo: _photos[index],
                            onRemove: () =>
                                setState(() => _photos.removeAt(index)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: Text(
                            _isSubmitting
                                ? 'Submitting...'
                                : 'Submit Verification',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
      ),
    );
  }
}

/// Resolves the private evidence photos as one group so the same signed URLs
/// can be used for both thumbnails and the full-screen swipe/zoom gallery.
class _EvidencePhotoGrid extends StatelessWidget {
  const _EvidencePhotoGrid({required this.paths, required this.controller});

  final List<String> paths;
  final AssetLossReportController controller;

  static const _brokenImage = ColoredBox(
    color: Color(0xFFF2F2F2),
    child: Icon(Icons.broken_image_outlined, color: Colors.grey),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: controller.getSignedPhotoUrls(paths),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final urls = snapshot.data ?? const [];
        if (urls.isEmpty) {
          return const Text(
            'Photos unavailable',
            style: TextStyle(color: Colors.grey),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: urls.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.responsive(
              mobile: 3,
              tablet: 4,
              desktop: 5,
            ),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) =>
                      PhotoGalleryViewer(urls: urls, initialIndex: index),
                ),
              ),
              child: Image.network(
                urls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _brokenImage,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shown in place of the verification form when the report can no longer be
/// verified by a helper.
class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice({required this.settled, required this.status});

  final bool settled;
  final String status;

  @override
  Widget build(BuildContext context) {
    final message = settled
        ? 'An admin has already ${status == 'rejected' ? 'rejected' : 'approved'} '
              'this report — no verification is needed.'
        : 'This report has already been verified and is now awaiting the '
              'admin\'s approval. Only an admin can change the outcome now.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
