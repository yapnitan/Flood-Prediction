import 'package:flutter/material.dart';
import '../../models/account.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../utils/validators.dart';

class PersonalInformationView extends StatefulWidget {
  final Account account;

  const PersonalInformationView({super.key, required this.account});

  @override
  State<PersonalInformationView> createState() =>
      _PersonalInformationViewState();
}

class _PersonalInformationViewState extends State<PersonalInformationView> {
  late final TextEditingController _nameController;
  final _authController = AuthController(AuthService());

  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty');
      return;
    }
    final wordCount = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount > 20) {
      setState(() => _errorMessage = 'Name cannot exceed 20 words');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    final ok = await _authController.updateProfile(
      id: widget.account.id,
      name: name,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, widget.account.copyWith(name: name));
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save changes';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personal Information'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              context.responsive(mobile: 20, tablet: 32, desktop: 40),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.responsive(mobile: 520, tablet: 560),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage.isNotEmpty) ...[
                      Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: _nameController,
                      inputFormatters: const [WordCountInputFormatter(20)],
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        hintText: 'Maximum 20 words',
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(
                        text: widget.account.email,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        helperText: 'Email cannot be changed here.',
                        prefixIcon: const Icon(Icons.email, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      enabled: false,
                      controller: TextEditingController(
                        text: widget.account.role,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
