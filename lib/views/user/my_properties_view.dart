import 'package:flutter/material.dart';
import '../../controllers/property_controller.dart';
import '../../models/property.dart';
import '../../services/property_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';
import 'property_form_view.dart';

/// Reached from Profile > Saved Locations — lets a resident add and view
/// the properties they own, independent of the repair-request wizard's
/// inline "Add new property" shortcut (both write through the same
/// [PropertyController]).
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
    _propertiesFuture = _controller.getMyProperties();
  }

  Future<void> _refresh() async {
    setState(() {
      _propertiesFuture = _controller.getMyProperties();
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

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: properties.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _PropertyCard(
                      property: properties[index],
                      onTap: () => _editProperty(properties[index]),
                      onDelete: () => _deleteProperty(properties[index]),
                    ),
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
  const _PropertyCard({required this.property, required this.onTap, required this.onDelete});

  final Property property;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
              'Estimated value: RM ${property.estimatedValue!.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
