import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About FloodWatch'), centerTitle: true),
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
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          "assets/images/logo.png",
                          width: 100,
                          height: 100,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.water, size: 80, color: Colors.blue),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'FloodWatch',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'FloodWatch is a flood risk management app for Malaysia. It '
                    'combines official JPS/DID historical flood records, terrain '
                    'elevation, and live weather data to help you assess a '
                    'property\'s flood risk, track community flood reports, and '
                    'prepare mitigation plans.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: const [
                        ListTile(
                          leading: Icon(Icons.map_outlined, color: Colors.blue),
                          title: Text('Historical flood data'),
                          subtitle: Text('JPS/DID (Jabatan Pengairan dan Saliran)'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.terrain_outlined, color: Colors.blue),
                          title: Text('Terrain & weather data'),
                          subtitle: Text('Open-Meteo Elevation & Forecast APIs'),
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
