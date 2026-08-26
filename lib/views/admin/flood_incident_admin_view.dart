import 'package:flutter/material.dart';

import '../../controllers/flood_incident_controller.dart';
import '../../models/flood_incident.dart';
import '../../services/flood_incident_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';

class FloodIncidentAdminView extends StatefulWidget {
  const FloodIncidentAdminView({super.key});

  @override
  State<FloodIncidentAdminView> createState() => _FloodIncidentAdminViewState();
}

class _FloodIncidentAdminViewState extends State<FloodIncidentAdminView> {
  final _controller = FloodIncidentController(FloodIncidentService());
  late Future<List<FloodIncident>> _incidentsFuture;

  @override
  void initState() {
    super.initState();
    _incidentsFuture = _controller.getAll();
  }

  Future<void> _refresh() async {
    setState(() {
      _incidentsFuture = _controller.getAll();
    });
    await _incidentsFuture;
  }

  Future<void> _addIncident() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Flood Incident'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Flood Incident #001'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final ok = await _controller.create(FloodIncident(
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                startedAt: DateTime.now(),
              ));
              if (context.mounted) Navigator.pop(context, ok);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) _refresh();
  }

  Future<void> _closeIncident(FloodIncident incident) async {
    await _controller.close(incident.id!);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Flood Incidents'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIncident,
        tooltip: 'New incident',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<FloodIncident>>(
                future: _incidentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final incidents = snapshot.data ?? [];
                  if (incidents.isEmpty) {
                    return const EmptyState(
                      icon: Icons.water_damage_outlined,
                      title: 'No flood incidents yet',
                      subtitle: 'Tap + to create one — users can then optionally link their reports to it.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: incidents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final incident = incidents[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(incident.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(
                                    incident.isActive ? 'Active since ${_formatDate(incident.startedAt)}' : 'Ended ${_formatDate(incident.endedAt!)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  if (incident.description != null && incident.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(incident.description!, style: const TextStyle(fontSize: 13)),
                                  ],
                                ],
                              ),
                            ),
                            if (incident.isActive)
                              TextButton(onPressed: () => _closeIncident(incident), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
