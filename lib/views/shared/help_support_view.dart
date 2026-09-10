import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/responsive.dart';

class HelpSupportView extends StatelessWidget {
  const HelpSupportView({super.key});

  static const _supportEmail = 'support@floodwatch.my';
  static const _supportPhone = '+60 3-1234 5678';

  Future<void> _launch(BuildContext context, Uri uri, String failureMessage) async {
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  void _emailSupport(BuildContext context) {
    _launch(context, Uri(scheme: 'mailto', path: _supportEmail), 'Could not open an email app.');
  }

  void _callSupport(BuildContext context) {
    final digits = _supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    _launch(context, Uri(scheme: 'tel', path: digits), 'Could not start a call.');
  }

  static const _faqs = [
    (
      'How is my flood risk score calculated?',
      'FloodWatch combines nearby historical flood records, your property\'s '
          'elevation relative to the surrounding area, structure type, and any '
          'flood barriers or raised foundations you\'ve added.',
    ),
    (
      'Where does the historical flood data come from?',
      'From the official JPS/DID (Jabatan Pengairan dan Saliran) flood '
          'dataset published by the Malaysian government.',
    ),
    (
      'Why isn\'t current weather part of my risk score?',
      'Weather is a snapshot of the moment, not a permanent property risk '
          'factor, so it\'s shown separately as "current conditions" instead of '
          'affecting your score.',
    ),
    (
      'How do I report a flood I\'m seeing right now?',
      'Use the "Submit Report" tab on the home screen to log the flood type, '
          'water level, and location.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            context.responsive(mobile: 20, tablet: 32, desktop: 40),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(mobile: 600, tablet: 680),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._faqs.map(
                    (faq) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        title: Text(
                          faq.$1,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                faq.$2,
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Contact Us',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email_outlined, color: Colors.blue),
                          title: const Text(_supportEmail),
                          subtitle: const Text('Email support'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _emailSupport(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.phone_outlined, color: Colors.blue),
                          title: const Text(_supportPhone),
                          subtitle: const Text('Mon–Fri, 9am–6pm'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _callSupport(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
