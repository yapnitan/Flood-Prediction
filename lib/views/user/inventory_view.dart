import 'package:flutter/material.dart';

import '../../controllers/planner_controller.dart';
import '../../models/inventory_item.dart';
import '../../services/planner_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/adaptive_search_filter_header.dart';
import '../../widgets/empty_state.dart';

/// Inventory CRUD (CLAUDE.md Task 8), plus Task 9's search + categories.
class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final _controller = PlannerController(PlannerService());
  final _searchController = TextEditingController();
  late Future<List<InventoryItem>> _itemsFuture;

  String _searchQuery = '';
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _itemsFuture = _controller.getInventory();
    });
  }

  List<InventoryItem> _applyFilters(List<InventoryItem> items) {
    return items.where((item) {
      if (_categoryFilter != 'All' && item.category != _categoryFilter)
        return false;
      if (_searchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _showItemDialog({InventoryItem? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final quantityController = TextEditingController(
      text: (existing?.quantity ?? 1).toString(),
    );
    final unitController = TextEditingController(text: existing?.unit ?? '');
    String category = existing?.category ?? InventoryItem.categoryOptions.first;
    DateTime? expiryDate = existing?.expiryDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Add inventory item' : 'Edit inventory item',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Item name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: InventoryItem.categoryOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => category = value ?? category),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit (optional)',
                          hintText: 'e.g. bottles',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expiryDate == null
                            ? 'No expiry date set'
                            : 'Expires: ${expiryDate!.day.toString().padLeft(2, '0')}/${expiryDate!.month.toString().padLeft(2, '0')}/${expiryDate!.year}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: expiryDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 1),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked != null)
                          setDialogState(() => expiryDate = picked);
                      },
                      child: const Text('Pick date'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final item = InventoryItem(
                  id: existing?.id,
                  name: name,
                  category: category,
                  quantity: int.tryParse(quantityController.text.trim()) ?? 1,
                  unit: unitController.text.trim().isEmpty
                      ? null
                      : unitController.text.trim(),
                  expiryDate: expiryDate,
                );
                final ok = existing == null
                    ? await _controller.createInventoryItem(item)
                    : await _controller.updateInventoryItem(
                        existing.id!,
                        item.toJson(),
                      );
                if (context.mounted) Navigator.pop(context, ok);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) _refresh();
  }

  Future<void> _delete(InventoryItem item) async {
    await _controller.deleteInventoryItem(item.id!);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = ['All', ...InventoryItem.categoryOptions];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showItemDialog(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AdaptiveSearchFilterHeader(
                    searchField: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search inventory',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _searchController.clear,
                              ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    portraitFilters: [
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryOptions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = categoryOptions[index];
                            final selected = _categoryFilter == category;
                            return ChoiceChip(
                              label: Text(category),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _categoryFilter = category),
                            );
                          },
                        ),
                      ),
                    ],
                    sheetTitle: 'Filter inventory',
                    activeFilterCount: _categoryFilter == 'All' ? 0 : 1,
                    sheetBuilder: (context, setSheetState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final category in categoryOptions)
                              ChoiceChip(
                                label: Text(category),
                                selected: _categoryFilter == category,
                                onSelected: (_) {
                                  setState(() => _categoryFilter = category);
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: FutureBuilder<List<InventoryItem>>(
                      future: _itemsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final items = _applyFilters(snapshot.data ?? []);
                        if (items.isEmpty) {
                          return const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No inventory items yet',
                            subtitle: 'Tap + to add one.',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isExpiringSoon =
                                item.expiryDate != null &&
                                item.expiryDate!.isBefore(
                                  DateTime.now().add(const Duration(days: 30)),
                                );
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.category} · ${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (item.expiryDate != null)
                                          Text(
                                            'Expires ${item.expiryDate!.day.toString().padLeft(2, '0')}/${item.expiryDate!.month.toString().padLeft(2, '0')}/${item.expiryDate!.year}',
                                            style: TextStyle(
                                              color: isExpiringSoon
                                                  ? Colors.red
                                                  : Colors.grey,
                                              fontSize: 12,
                                              fontWeight: isExpiringSoon
                                                  ? FontWeight.bold
                                                  : null,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showItemDialog(existing: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _delete(item),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
