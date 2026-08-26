import 'package:flutter/material.dart';

import '../../constants/asset_categories.dart';
import '../../controllers/asset_loss_report_controller.dart';
import '../../services/asset_loss_report_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';

class AssetLossAdminDetailView extends StatefulWidget {
  const AssetLossAdminDetailView({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<AssetLossAdminDetailView> createState() => _AssetLossAdminDetailViewState();
}

class _AssetLossAdminDetailViewState extends State<AssetLossAdminDetailView> {
  final _controller = AssetLossReportController(AssetLossReportService());
  late Map<String, dynamic> _data;
  bool _isBusy = false;

  late final TextEditingController _approvedQuantityController;
  late final TextEditingController _approvedValueController;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);

    // Default the approval figure to the helper's verified figure if one
    // exists, otherwise the resident's originally reported figure (§30 —
    // the admin can approve directly even with no helper verification yet).
    final quantity = _data['verified_quantity'] ?? _data['quantity'];
    final value = _data['verified_value_per_item'] ?? _data['estimated_value_per_item'];
    _approvedQuantityController = TextEditingController(text: '$quantity');
    _approvedValueController = TextEditingController(text: '$value');
  }

  @override
  void dispose() {
    _approvedQuantityController.dispose();
    _approvedValueController.dispose();
    super.dispose();
  }

  String get _id => _data['id'] as String;
  String get _status => _data['status'] as String? ?? 'pending_review';

  Future<void> _run(Future<void> Function() action, {Map<String, dynamic>? localUpdate}) async {
    setState(() => _isBusy = true);
    await action();
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (localUpdate != null) _data.addAll(localUpdate);
    });
  }

  Future<void> _approve() async {
    final quantity = int.tryParse(_approvedQuantityController.text.trim());
    final value = double.tryParse(_approvedValueController.text.trim());
    if (quantity == null || quantity <= 0 || value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid approved quantity and value.')),
      );
      return;
    }
    await _run(
      () => _controller.approve(reportId: _id, approvedQuantity: quantity, approvedValuePerItem: value),
      localUpdate: {
        'status': 'verified',
        'approved_quantity': quantity,
        'approved_value_per_item': value,
        'approved_total_loss': quantity * value,
      },
    );
  }

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this report?'),
        content: const Text('It will not contribute to the Economic Loss Dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _controller.reject(_id), localUpdate: {'status': 'rejected'});
  }

  @override
  Widget build(BuildContext context) {
    final account = _data['account'] as Map<String, dynamic>?;
    final property = _data['property'] as Map<String, dynamic>?;
    final incident = _data['flood_incident'] as Map<String, dynamic>?;
    final photoPaths = (_data['photo_paths'] as List?)?.cast<String>() ?? const [];
    final verificationPhotoPaths = (_data['verification_photo_paths'] as List?)?.cast<String>() ?? const [];
    final estimatedTotal = (_data['estimated_total_loss'] as num?)?.toDouble() ?? 0;
    final verifiedTotal = (_data['verified_total_loss'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Asset Loss Report'), centerTitle: true),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isBusy,
          child: Stack(
            children: [
              SingleChildScrollView(
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
                                '${_data['asset_category']} — ${_data['asset_name']}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            StatusBadge(status: _status),
                          ],
                        ),
                        if (account != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'From: ${account['name'] ?? 'Unknown'} (${account['email'] ?? ''})',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (property != null)
                          ReviewCard(
                            title: 'Address',
                            value: '${property['label'] ?? ''} ${property['address'] ?? ''}\n'
                                '${property['district'] ?? ''}, ${property['state'] ?? ''}'.trim(),
                          ),
                        if (incident != null) ReviewCard(title: 'Flood incident', value: incident['name'] as String),
                        ReviewCard(
                          title: 'Condition',
                          value: assetConditionLabels[_data['condition']] ?? '${_data['condition']}',
                        ),
                        ReviewCard(title: 'Quantity', value: '${_data['quantity']}'),
                        ReviewCard(
                          title: 'Estimated value per item',
                          value: 'RM ${(_data['estimated_value_per_item'] as num).toStringAsFixed(2)}',
                        ),
                        ReviewCard(
                          title: 'Potential Asset Loss (user-reported)',
                          value: 'RM ${estimatedTotal.toStringAsFixed(2)}',
                        ),
                        if ((_data['description'] as String?)?.trim().isNotEmpty ?? false)
                          ReviewCard(title: 'Description', value: _data['description'] as String),
                        if (_data['created_at'] != null)
                          ReviewCard(title: 'Submitted', value: _formatDate(DateTime.parse(_data['created_at'] as String))),

                        const SizedBox(height: 12),
                        const Text('Evidence Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 10),
                        if (photoPaths.isEmpty)
                          const Text('No photos attached', style: TextStyle(color: Colors.grey))
                        else
                          _PhotoGrid(paths: photoPaths, controller: _controller),

                        if (_data['verification_result'] != null) ...[
                          const Divider(height: 32),
                          const Text('Helper Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 10),
                          ReviewCard(
                            title: 'Result',
                            value: verificationResultLabels[_data['verification_result']] ?? '${_data['verification_result']}',
                          ),
                          ReviewCard(title: 'Verified quantity', value: '${_data['verified_quantity']}'),
                          ReviewCard(
                            title: 'Verified value per item',
                            value: 'RM ${(_data['verified_value_per_item'] as num).toStringAsFixed(2)}',
                          ),
                          if (verifiedTotal != null)
                            ReviewCard(title: 'Verified loss', value: 'RM ${verifiedTotal.toStringAsFixed(2)}'),
                          if ((_data['verification_notes'] as String?)?.trim().isNotEmpty ?? false)
                            ReviewCard(title: 'Notes', value: _data['verification_notes'] as String),
                          if (verificationPhotoPaths.isNotEmpty) ...[
                            const Text('Verification Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            _PhotoGrid(paths: verificationPhotoPaths, controller: _controller),
                          ],
                        ],

                        if (_status == 'pending_review') ...[
                          const Divider(height: 32),
                          const Text('Admin Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _approvedQuantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Approved quantity', border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _approvedValueController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Approved value/item',
                                    prefixText: 'RM ',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _reject,
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _approve,
                                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                                  label: const Text('Approve', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ] else if (_status == 'verified' && _data['approved_total_loss'] != null) ...[
                          const Divider(height: 32),
                          ReviewCard(
                            title: 'Approved loss',
                            value: 'RM ${(_data['approved_total_loss'] as num).toStringAsFixed(2)}',
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isBusy)
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x33000000), child: Center(child: CircularProgressIndicator())),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.paths, required this.controller});

  final List<String> paths;
  final AssetLossReportController controller;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: paths.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => NetworkPhotoThumbnail(
        storagePath: paths[index],
        urlResolver: controller.getSignedPhotoUrl,
      ),
    );
  }
}
