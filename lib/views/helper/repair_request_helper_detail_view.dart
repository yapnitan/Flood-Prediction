import 'package:flutter/material.dart';
import '../../controllers/repair_request_controller.dart';
import '../../models/repair_request.dart';
import '../../utils/maps_launcher.dart';
import '../../widgets/network_photo_thumbnail.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/review_card.dart';
import '../../widgets/status_badge.dart';

class RepairRequestHelperDetailView extends StatefulWidget {
  const RepairRequestHelperDetailView({
    super.key,
    required this.request,
    required this.controller,
  });

  final RepairRequest request;
  final RepairRequestController controller;

  @override
  State<RepairRequestHelperDetailView> createState() => _RepairRequestHelperDetailViewState();
}

class _RepairRequestHelperDetailViewState extends State<RepairRequestHelperDetailView> {
  late String _status;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.request.status;
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isBusy = true);
    await widget.controller.updateStatus(widget.request.id!, status);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Task Details'), centerTitle: true),
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
                            request.assistanceType,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusBadge(status: _status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PriorityBadge(priority: request.priority),
                    const SizedBox(height: 20),
                    ReviewCard(title: 'Location', value: request.locationName),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => openDirections(
                          context,
                          latitude: request.latitude,
                          longitude: request.longitude,
                        ),
                        icon: const Icon(Icons.directions),
                        label: const Text('Get directions'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          side: const BorderSide(color: Colors.indigo),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ReviewCard(title: 'Damage description', value: request.damageDescription),
                    if (request.contactNumber != null && request.contactNumber!.isNotEmpty)
                      ReviewCard(title: 'Contact number', value: request.contactNumber!),
                    if (request.shelterName != null)
                      ReviewCard(title: 'Shelter', value: request.shelterName!),

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
                          repairRequestService: widget.controller.repairRequestService,
                        ),
                      ),

                    const SizedBox(height: 30),
                    if (_status == 'assigned')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus('in_progress'),
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          label: const Text('Start task', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                        ),
                      )
                    else if (_status == 'in_progress')
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus('completed'),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: const Text('Mark completed', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      )
                    else if (_status == 'completed')
                        const Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: Colors.green),
                            SizedBox(width: 6),
                            Text('Task completed', style: TextStyle(color: Colors.green)),
                          ],
                        ),
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
}