import 'package:flutter/material.dart';
import '../../controllers/repair_request_controller.dart';
import '../../models/account.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';

class RepairRequestAdminDetailView extends StatefulWidget {
  const RepairRequestAdminDetailView({
    super.key,
    required this.data,
    required this.helpers,
    required this.controller,
  });

  final Map<String, dynamic> data;
  final List<Account> helpers;
  final RepairRequestController controller;

  @override
  State<RepairRequestAdminDetailView> createState() => _RepairRequestAdminDetailViewState();
}

class _RepairRequestAdminDetailViewState extends State<RepairRequestAdminDetailView> {
  late Map<String, dynamic> _data;
  late final TextEditingController _shelterController;
  bool _isBusy = false;

  static const _priorities = ['low', 'medium', 'high', 'urgent'];

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    _shelterController = TextEditingController(text: _data['shelter_name'] as String? ?? '');
  }

  @override
  void dispose() {
    _shelterController.dispose();
    super.dispose();
  }

  String get _id => _data['id'] as String;
  String get _status => _data['status'] as String? ?? 'pending';

  Future<void> _run(Future<void> Function() action, {Map<String, dynamic>? localUpdate}) async {
    setState(() => _isBusy = true);
    await action();
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (localUpdate != null) _data.addAll(localUpdate);
    });
  }

  Future<void> _approve() => _run(
        () => widget.controller.approveRequest(_id),
    localUpdate: {'status': 'approved'},
  );

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this request?'),
        content: const Text('The requester will see this as rejected.'),
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
    await _run(
          () => widget.controller.rejectRequest(_id),
      localUpdate: {'status': 'rejected'},
    );
  }

  Future<void> _setPriority(String priority) => _run(
        () => widget.controller.setPriority(_id, priority),
    localUpdate: {'priority': priority},
  );

  Future<void> _assignHelper(String helperId) => _run(
        () => widget.controller.assignHelper(_id, helperId),
    localUpdate: {'assigned_helper_id': helperId, 'status': 'assigned'},
  );

  Future<void> _saveShelter() async {
    final name = _shelterController.text.trim();
    if (name.isEmpty) return;
    await _run(
          () => widget.controller.setShelter(_id, name),
      localUpdate: {'shelter_name': name},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shelter saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = _data['priority'] as String? ?? 'medium';
    final account = _data['account'] as Map<String, dynamic>?;
    final assignedHelperId = _data['assigned_helper_id'] as String?;
    final photoPaths = (_data['photo_paths'] as List?)?.cast<String>() ?? const [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Request Details'), centerTitle: true),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isBusy,
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _data['assistance_type'] as String? ?? '',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusBadge(status: _status),
                      ],
                    ),
                    if (account != null) ...[
                      const SizedBox(height: 6),
                      Text('From: ${account['name'] ?? 'Unknown'} (${account['email'] ?? ''})',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                    const SizedBox(height: 20),
                    ReviewCard(title: 'Location', value: _data['location_name'] as String? ?? ''),
                    ReviewCard(title: 'Damage description', value: _data['damage_description'] as String? ?? ''),
                    if ((_data['contact_number'] as String?)?.isNotEmpty ?? false)
                      ReviewCard(title: 'Contact number', value: _data['contact_number'] as String),
                    if (_data['created_at'] != null)
                      ReviewCard(title: 'Submitted', value: _formatDate(DateTime.parse(_data['created_at'] as String))),

                    const SizedBox(height: 12),
                    const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                          repairRequestService: widget.controller.repairRequestService,
                        ),
                      ),

                    const SizedBox(height: 24),
                    const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: _priorities.map((p) {
                        final selected = priority == p;
                        return ChoiceChip(
                          label: Text(p),
                          selected: selected,
                          onSelected: (_) => _setPriority(p),
                          selectedColor: p == 'urgent' ? Colors.red.shade100 : Colors.blue.shade100,
                          labelStyle: TextStyle(
                            color: selected
                                ? (p == 'urgent' ? Colors.red.shade900 : Colors.blue.shade900)
                                : Colors.black87,
                          ),
                        );
                      }).toList(),
                    ),

                    if (_status == 'pending') ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _reject,
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
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
                    ],

                    if (_status == 'approved' || _status == 'assigned' || _status == 'in_progress') ...[
                      const SizedBox(height: 24),
                      const Text('Assign Helper', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: assignedHelperId,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        items: widget.helpers
                            .map((h) => DropdownMenuItem(value: h.id, child: Text(h.name)))
                            .toList(),
                        onChanged: widget.helpers.isEmpty
                            ? null
                            : (value) {
                          if (value != null) _assignHelper(value);
                        },
                        hint: Text(widget.helpers.isEmpty ? 'No active helpers available' : 'Select a helper'),
                      ),
                      const SizedBox(height: 20),
                      const Text('Shelter / Evacuation Centre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _shelterController,
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _saveShelter,
                            icon: const Icon(Icons.check),
                            tooltip: 'Save shelter',
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              if (_isBusy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
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