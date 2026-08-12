import 'package:flutter/material.dart';
import '../../controllers/repair_request_controller.dart';
import '../../models/repair_request.dart';
import '../../services/repair_request_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/review_card.dart';
import '../../widgets/selectable_chip.dart';
import '../../widgets/status_badge.dart';

class RepairRequestDetailView extends StatefulWidget {
  const RepairRequestDetailView({super.key, required this.requestId});

  final String requestId;

  @override
  State<RepairRequestDetailView> createState() => _RepairRequestDetailViewState();
}

class _RepairRequestDetailViewState extends State<RepairRequestDetailView> {
  final _service = RepairRequestService();
  late final _controller = RepairRequestController(_service);
  late Future<RepairRequest?> _requestFuture;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isCancelling = false;

  // Edit-mode state
  final _editFormKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  String? _editAssistanceType;

  final List<String> assistanceTypes = [
    'Structural Repair',
    'Temporary Shelter',
    'Food & Water Supply',
    'Medical Assistance',
    'Financial Aid',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _requestFuture = _controller.getRequestById(widget.requestId);
  }

  @override
  void dispose() {
    if (_isEditing) {
      _descriptionController.dispose();
    }
    super.dispose();
  }

  void _startEditing(RepairRequest request) {
    _descriptionController = TextEditingController(text: request.damageDescription);
    _editAssistanceType = request.assistanceType;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _descriptionController.dispose();
    setState(() => _isEditing = false);
  }

  Future<void> _saveEdits() async {
    if (!(_editFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    await _controller.updateRequest(
      widget.requestId,
      assistanceType: _editAssistanceType,
      damageDescription: _descriptionController.text.trim(),
    );

    if (!mounted) return;
    _descriptionController.dispose();
    setState(() {
      _isSaving = false;
      _isEditing = false;
      _requestFuture = _controller.getRequestById(widget.requestId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request updated.')),
    );
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('This cannot be undone. You\'ll need to submit a new request if you still need help.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    await _controller.cancelRequest(widget.requestId);
    if (!mounted) return;

    setState(() {
      _isCancelling = false;
      _requestFuture = _controller.getRequestById(widget.requestId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request cancelled.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Request Details'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
            ),
            child: FutureBuilder<RepairRequest?>(
              future: _requestFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final request = snapshot.data;
                if (request == null) {
                  return const Center(child: Text('Request not found.'));
                }

                return _isEditing ? _buildEditForm(request) : _buildDetailView(request);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView(RepairRequest request) {
    final canEdit = request.status == 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                request.assistanceType,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              StatusBadge(status: request.status),
            ],
          ),
          const SizedBox(height: 20),
          ReviewCard(title: 'Location', value: request.locationName),
          ReviewCard(title: 'Damage description', value: request.damageDescription),
          if (request.contactNumber != null && request.contactNumber!.isNotEmpty)
            ReviewCard(title: 'Contact number', value: request.contactNumber!),
          ReviewCard(
            title: 'Priority',
            value: request.priority[0].toUpperCase() + request.priority.substring(1),
          ),
          if (request.shelterName != null)
            ReviewCard(title: 'Assigned shelter', value: request.shelterName!),
          if (request.createdAt != null)
            ReviewCard(title: 'Submitted', value: _formatDate(request.createdAt!)),
          const SizedBox(height: 12),
          const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (request.photoPaths.isEmpty)
            const Text('No photos attached', style: TextStyle(color: Colors.grey))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: request.photoPaths.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) => NetworkPhotoThumbnail(
                storagePath: request.photoPaths[index],
                repairRequestService: _service,
              ),
            ),
          const SizedBox(height: 32),
          if (canEdit) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _startEditing(request),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit request'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isCancelling ? null : _confirmCancel,
                icon: _isCancelling
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.cancel_outlined),
                label: Text(_isCancelling ? 'Cancelling...' : 'Cancel request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lockedReasonText(request.status),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _lockedReasonText(String status) {
    switch (status) {
      case 'cancelled':
        return 'This request was cancelled and can no longer be edited.';
      case 'rejected':
        return 'This request was rejected. Submit a new request if you still need assistance.';
      default:
        return 'This request is already being processed and can no longer be edited or cancelled.';
    }
  }

  Widget _buildEditForm(RepairRequest request) {
    final gridColumns = context.screenWidth >= 900 ? 4 : (context.screenWidth >= 600 ? 3 : 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _editFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('Type of Assistance Needed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                  selected: _editAssistanceType == type,
                  onTap: () => setState(() => _editAssistanceType = type),
                ),
              )
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Damage description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a short description.' : null,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      child: const Text('Discard'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEdits,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isSaving ? 'Saving...' : 'Save changes',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}