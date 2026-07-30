import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class HelpSupportView extends StatelessWidget {
  const HelpSupportView({super.key});

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
                      children: const [
                        ListTile(
                          leading: Icon(Icons.email_outlined, color: Colors.blue),
                          title: Text('support@floodwatch.my'),
                          subtitle: Text('Email support'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.phone_outlined, color: Colors.blue),
                          title: Text('+60 3-1234 5678'),
                          subtitle: Text('Mon–Fri, 9am–6pm'),
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
