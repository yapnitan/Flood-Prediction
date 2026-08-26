import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/planner_controller.dart';
import '../../models/emergency_contact.dart';
import '../../services/planner_service.dart';
import '../../utils/responsive.dart';
import '../../utils/validators.dart';
import '../../widgets/empty_state.dart';

/// Emergency Contacts CRUD (CLAUDE.md Task 8).
class ContactsView extends StatefulWidget {
  const ContactsView({super.key});

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  final _controller = PlannerController(PlannerService());
  late Future<List<EmergencyContact>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _contactsFuture = _controller.getContacts();
    });
  }

  Future<void> _showContactDialog({EmergencyContact? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    String? relationship = existing?.relationship;
    String? phoneError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add contact' : 'Edit contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'Phone number', errorText: phoneError),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: EmergencyContact.relationshipOptions.contains(relationship)
                      ? relationship
                      : null,
                  decoration: const InputDecoration(labelText: 'Relationship (optional)'),
                  items: EmergencyContact.relationshipOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => relationship = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  minLines: 1,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty) return;
                final error = requiredPhoneNumber(phone);
                if (error != null) {
                  setDialogState(() => phoneError = error);
                  return;
                }
                final contact = EmergencyContact(
                  id: existing?.id,
                  name: name,
                  phoneNumber: phone,
                  relationship: relationship,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );
                final ok = existing == null
                    ? await _controller.createContact(contact)
                    : await _controller.updateContact(existing.id!, contact.toJson());
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

  Future<void> _delete(EmergencyContact contact) async {
    await _controller.deleteContact(contact.id!);
    _refresh();
  }

  Future<void> _call(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactDialog(),
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
              child: FutureBuilder<List<EmergencyContact>>(
                future: _contactsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final contacts = snapshot.data ?? [];
                  if (contacts.isEmpty) {
                    return const EmptyState(
                      icon: Icons.contact_phone_outlined,
                      title: 'No emergency contacts yet',
                      subtitle: 'Tap + to add one.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: contacts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.withValues(alpha: 0.15),
                              child: Text(
                                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    [
                                      if (contact.relationship != null) contact.relationship!,
                                      contact.phoneNumber,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () => _call(contact.phoneNumber),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showContactDialog(existing: contact),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () => _delete(contact),
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
        ),
      ),
    );
  }
}
