import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/planner_controller.dart';
import '../../models/checklist_item.dart';
import '../../models/emergency_checklist.dart';
import '../../services/planner_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/empty_state.dart';

/// Emergency Checklist CRUD (CLAUDE.md Task 8) — a user can keep several
/// named checklists (e.g. "Home go-bag"), each with its own checked-off
/// items. Preparation progress on [PlannerDashboardView] is computed from
/// every item across every checklist here.
class ChecklistView extends StatefulWidget {
  const ChecklistView({super.key});

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<ChecklistView> {
  final _controller = PlannerController(PlannerService());
  late Future<List<EmergencyChecklist>> _checklistsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _checklistsFuture = _controller.getChecklists();
    });
  }

  Future<void> _createChecklist() async {
    final title = await _promptForText(context, title: 'New checklist', label: 'Checklist name');
    if (title == null || title.trim().isEmpty) return;
    await _controller.createChecklist(title.trim());
    _refresh();
  }

  Future<void> _renameChecklist(EmergencyChecklist checklist) async {
    final title = await _promptForText(
      context,
      title: 'Rename checklist',
      label: 'Checklist name',
      initialValue: checklist.title,
    );
    if (title == null || title.trim().isEmpty) return;
    await _controller.renameChecklist(checklist.id!, title.trim());
    _refresh();
  }

  Future<void> _deleteChecklist(EmergencyChecklist checklist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this checklist?'),
        content: Text('"${checklist.title}" and all its items will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _controller.deleteChecklist(checklist.id!);
    _refresh();
  }

  /// Task 9 "export checklist" — builds a plain-text summary of every
  /// checklist and its items, and hands it to the OS share sheet (so it can
  /// go to Notes, email, WhatsApp, etc. — no bespoke file format needed).
  Future<void> _exportChecklists() async {
    final checklists = await _checklistsFuture;
    if (checklists.isEmpty) return;

    final buffer = StringBuffer('Flood Watch — Emergency Checklists\n\n');
    for (final checklist in checklists) {
      buffer.writeln(checklist.title);
      final items = await _controller.getItems(checklist.id!);
      if (items.isEmpty) {
        buffer.writeln('  (no items)');
      } else {
        for (final item in items) {
          buffer.writeln('  [${item.isChecked ? 'x' : ' '}] ${item.label}');
        }
      }
      buffer.writeln();
    }

    if (!mounted) return;
    await SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Emergency Checklists'));
  }

  Future<String?> _promptForText(
    BuildContext context, {
    required String title,
    required String label,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Emergency Checklist'),
        actions: [
          IconButton(
            tooltip: 'Export checklists',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportChecklists,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createChecklist,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.responsive(mobile: 700, tablet: 800, desktop: 900),
            ),
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<EmergencyChecklist>>(
                future: _checklistsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final checklists = snapshot.data ?? [];
                  if (checklists.isEmpty) {
                    return const EmptyState(
                      icon: Icons.checklist_outlined,
                      title: 'No checklists yet',
                      subtitle: 'Tap + to create one.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: checklists.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ChecklistCard(
                      key: ValueKey(checklists[index].id),
                      checklist: checklists[index],
                      controller: _controller,
                      onRename: () => _renameChecklist(checklists[index]),
                      onDelete: () => _deleteChecklist(checklists[index]),
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

class _ChecklistCard extends StatefulWidget {
  const _ChecklistCard({
    super.key,
    required this.checklist,
    required this.controller,
    required this.onRename,
    required this.onDelete,
  });

  final EmergencyChecklist checklist;
  final PlannerController controller;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  /// Held as a mutable list (not a re-assigned Future) so checking an item
  /// updates it in place — no refetch, no FutureBuilder spinner flash, and
  /// the ExpansionTile stays open. The DB write happens in the background
  /// and only a failure triggers a revert.
  List<ChecklistItem>? _items;
  bool _loadFailed = false;
  final _newItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final items = await widget.controller.getItems(widget.checklist.id!);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(ChecklistItem item, bool checked) async {
    final items = _items;
    if (items == null) return;
    final index = items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;
    setState(() => items[index] = items[index].copyWith(isChecked: checked));
    final ok = await widget.controller
        .setItemChecked(item.id!, checked, widget.checklist.id!);
    if (!mounted || ok) return;
    setState(() => items[index] = items[index].copyWith(isChecked: !checked));
    _showError('Could not save that change.');
  }

  Future<void> _deleteItem(ChecklistItem item) async {
    final items = _items;
    if (items == null) return;
    final index = items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;
    final removed = items[index];
    setState(() => items.removeAt(index));
    final ok = await widget.controller
        .deleteItem(item.id!, widget.checklist.id!);
    if (!mounted || ok) return;
    setState(() => items.insert(index, removed));
    _showError('Could not delete that item.');
  }

  Future<void> _addItem() async {
    final label = _newItemController.text.trim();
    if (label.isEmpty) return;
    _newItemController.clear();
    final ok = await widget.controller.addItem(widget.checklist.id!, label);
    if (!mounted) return;
    if (ok) {
      // One refetch here (add is infrequent) so the new row picks up its
      // server-assigned id and sort order.
      await _loadItems();
    } else {
      _showError('Could not add that item.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          widget.checklist.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') widget.onRename();
            if (value == 'delete') widget.onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        children: [
          if (_items == null && !_loadFailed)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadFailed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(child: Text('Could not load items.')),
                  TextButton(onPressed: _loadItems, child: const Text('Retry')),
                ],
              ),
            )
          else ...[
            for (final item in _items!)
              CheckboxListTile(
                value: item.isChecked,
                title: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: item.isChecked
                      ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                      : null,
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                  onPressed: () => _deleteItem(item),
                ),
                onChanged: (checked) => _toggle(item, checked ?? false),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newItemController,
                      decoration: const InputDecoration(
                        hintText: 'Add an item',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.blue), onPressed: _addItem),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
