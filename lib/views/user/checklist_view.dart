import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/planner_controller.dart';
import '../../models/checklist_item.dart';
import '../../models/emergency_checklist.dart';
import '../../services/planner_service.dart';
import '../../utils/responsive.dart';

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
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No checklists yet — tap + to create one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: checklists.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ChecklistCard(
                      checklist: checklists[index],
                      controller: _controller,
                      onRename: () => _renameChecklist(checklists[index]),
                      onDelete: () => _deleteChecklist(checklists[index]),
                      onProgressChanged: _refresh,
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
    required this.checklist,
    required this.controller,
    required this.onRename,
    required this.onDelete,
    required this.onProgressChanged,
  });

  final EmergencyChecklist checklist;
  final PlannerController controller;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onProgressChanged;

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  late Future<List<ChecklistItem>> _itemsFuture;
  final _newItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.controller.getItems(widget.checklist.id!);
  }

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  void _reloadItems() {
    setState(() {
      _itemsFuture = widget.controller.getItems(widget.checklist.id!);
    });
    widget.onProgressChanged();
  }

  Future<void> _addItem() async {
    final label = _newItemController.text.trim();
    if (label.isEmpty) return;
    _newItemController.clear();
    await widget.controller.addItem(widget.checklist.id!, label);
    _reloadItems();
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
        title: Text(widget.checklist.title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          FutureBuilder<List<ChecklistItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? [];
              return Column(
                children: [
                  for (final item in items)
                    CheckboxListTile(
                      value: item.isChecked,
                      title: Text(
                        item.label,
                        style: item.isChecked
                            ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                            : null,
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                        onPressed: () async {
                          await widget.controller.deleteItem(item.id!);
                          _reloadItems();
                        },
                      ),
                      onChanged: (checked) async {
                        await widget.controller.setItemChecked(item.id!, checked ?? false);
                        _reloadItems();
                      },
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
              );
            },
          ),
        ],
      ),
    );
  }
}
