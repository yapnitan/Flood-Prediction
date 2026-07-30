import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_arguments.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfileState();
}

class _ProfileState extends State<ProfilePage> {
  final _authController = AuthController(AuthService());

  Account? _account;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    Account? account;
    if (userId != null) {
      account = await _authController.getAccount(userId);
    }
    if (!mounted) return;
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _authController.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = _account?.name.isNotEmpty == true ? _account!.name : 'Guest';
    final email = _account?.email ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),

      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---- Header with wave background + avatar ----
          _ProfileHeader(name: name, email: email),

          const SizedBox(height: 20),

          // ---- Settings list ----
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(
                  mobile: 600,
                  tablet: 680,
                  desktop: 720,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.responsive(
                    mobile: 16,
                    tablet: 24,
                    desktop: 32,
                  ),
                ),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.person_outline,
                      label: "Personal Information",
                      onTap: () async {
                        if (_account == null) return;
                        final updated = await Navigator.pushNamed<Account>(
                          context,
                          AppRoutes.personalInformation,
                          arguments: PersonalInformationArgs(_account!),
                        );
                        if (updated != null) setState(() => _account = updated);
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.notifications_none,
                      label: "Notification Settings",
                      onTap: () async {
                        if (_account == null) return;
                        final updated = await Navigator.pushNamed<Account>(
                          context,
                          AppRoutes.notificationSettings,
                          arguments: NotificationSettingsArgs(_account!),
                        );
                        if (updated != null) setState(() => _account = updated);
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.location_on_outlined,
                      label: "Saved Locations",
                      onTap: () {},
                    ),
                    _ProfileTile(
                      icon: Icons.description_outlined,
                      label: "Report History",
                      onTap: () {},
                    ),
                    _ProfileTile(
                      icon: Icons.help_outline,
                      label: "Help & Support",
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.helpSupport);
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.info_outline,
                      label: "About FloodWatch",
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.about);
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.logout,
                      label: "Log Out",
                      iconColor: Colors.red,
                      textColor: Colors.red,
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Wave-style header with avatar, name, and email.
class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;

  const _ProfileHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: context.responsive(mobile: 220.0, tablet: 240.0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Layered wave background
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              height: 170,
              width: double.infinity,
              color: const Color(0xFF9AC8EC),
            ),
          ),
          Positioned(
            top: 0,
            child: ClipPath(
              clipper: _WaveClipperBack(),
              child: Container(
                height: 150,
                width: MediaQuery.of(context).size.width,
                color: const Color(0xFF6FAEE0),
              ),
            ),
          ),

          // Avatar + text, anchored to bottom of the stack
          Positioned(
            bottom: 0,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 42,
                        backgroundColor: Color(0xFFE0ECF9),
                        child: Icon(
                          Icons.person,
                          size: 48,
                          color: Color(0xFF6FAEE0),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: iconColor ?? const Color(0xFF3B82F6)),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      ),
    );
  }
}

/// Front wave layer (lighter blue, sits on top)
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 20,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 40,
      size.width,
      size.height - 10,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Back wave layer (darker blue, sits behind)
class _WaveClipperBack extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 20);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height - 50,
      size.width * 0.6,
      size.height - 15,
    );
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height + 10,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
