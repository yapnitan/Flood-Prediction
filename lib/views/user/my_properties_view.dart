import 'package:flutter/material.dart';
import '../../controllers/property_controller.dart';
import '../../models/property.dart';
import '../../services/property_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';
import 'property_form_view.dart';

class MyPropertiesView extends StatefulWidget {
  const MyPropertiesView({super.key});

  @override
  State<MyPropertiesView> createState() => _MyPropertiesViewState();
}

class _MyPropertiesViewState extends State<MyPropertiesView> {
  final _controller = PropertyController(PropertyService());
  late Future<List<Property>> _propertiesFuture;

  @override
  void initState() {
    super.initState();
    _propertiesFuture = _controller.getMyProperties(includeArchived: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _propertiesFuture = _controller.getMyProperties(includeArchived: true);
    });
    await _propertiesFuture;
  }

  Future<void> _addProperty() async {
    final created = await Navigator.push<Property>(
      context,
      MaterialPageRoute(builder: (context) => PropertyFormView(controller: _controller)),
    );
    if (created != null) _refresh();
  }

  Future<void> _editProperty(Property property) async {
    final updated = await Navigator.push<Property>(
      context,
      MaterialPageRoute(builder: (context) => PropertyFormView(controller: _controller, existing: property)),
    );
    if (updated != null) _refresh();
  }

  Future<void> _deleteProperty(Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this address?'),
        content: Text(
          'This removes "${property.displayLabel}" from your saved locations. '
          "If it's linked to asset-loss reports it will be archived (hidden) "
          'rather than deleted, so those reports keep their location.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _controller.deleteProperty(property.id!);
    if (!mounted) return;
    if (result.message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message!)));
    }
    if (result.changed) _refresh();
  }

  Future<void> _restoreProperty(Property property) async {
    final ok = await _controller.restoreProperty(property.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '"${property.displayLabel}" restored to your saved locations.'
              : 'Could not restore this address. Please try again.',
        ),
      ),
    );
    if (ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Saved Locations'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProperty,
        tooltip: 'Add property',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900)),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Property>>(
                future: _propertiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load your properties',
                      subtitle: 'Pull down to try again.',
                    );
                  }

                  final properties = snapshot.data ?? [];
                  if (properties.isEmpty) {
                    return const EmptyState(
                      icon: Icons.other_houses_outlined,
                      title: 'No saved properties yet',
                      subtitle: 'Tap + to add a property — you can then select it '
                          'when reporting property damage.',
                    );
                  }

                  final active =
                      properties.where((p) => !p.isArchived).toList();
                  final archived =
                      properties.where((p) => p.isArchived).toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    children: [
                      for (final property in active) ...[
                        _PropertyCard(
                          property: property,
                          onTap: () => _editProperty(property),
                          onDelete: () => _deleteProperty(property),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (archived.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.archive_outlined,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Archived',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hidden because they are linked to asset-loss reports. '
                          'Restore one to use it again.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final property in archived) ...[
                          _PropertyCard(
                            property: property,
                            archived: true,
                            onRestore: () => _restoreProperty(property),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.property,
    this.onTap,
    this.onDelete,
    this.onRestore,
    this.archived = false,
  });

  final Property property;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: archived ? 0.65 : 1,
      child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.other_houses_outlined, color: Colors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  property.displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              if (archived)
                TextButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.unarchive_outlined, size: 18),
                  label: const Text('Restore'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (property.district != null && property.state != null) ...[
            const SizedBox(height: 8),
            Text(
              '${property.district}, ${property.state}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
          if (property.floors != null) ...[
            const SizedBox(height: 8),
            Text('Floors: ${property.floors}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
          if (property.estimatedValue != null) ...[
            const SizedBox(height: 4),
            Text(
              'Estimated value: ${formatRinggit(property.estimatedValue!)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ],
      ),
      ),
      ),
    );
  }
}
