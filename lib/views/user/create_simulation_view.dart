import 'package:flutter/material.dart';
import '../../controllers/risk_assessment_controller.dart';
import '../../controllers/historical_flood_controller.dart';
import '../../controllers/environment_controller.dart';
import '../../services/historical_flood_service.dart';
import '../../services/terrain_service.dart';
import '../../services/weather_service.dart';
import '../../services/risk_assessment_service.dart';
import '../../services/flood_simulation_service.dart';
import '../../utils/malaysia_geocoding.dart';
import '../../utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_arguments.dart';

class CreateSimulationView extends StatefulWidget {
  const CreateSimulationView({super.key});

  @override
  State<CreateSimulationView> createState() => _CreateSimulationViewState();
}

class _CreateSimulationViewState extends State<CreateSimulationView> {
  final _propertyNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _elevationController = TextEditingController();

  String _structureType = RiskAssessmentService.structureTypeOptions.first;
  String _state = MalaysiaGeocoder.states.first;
  bool _hasFloodBarriers = false;
  bool _hasRaisedFoundation = false;

  bool _isSubmitting = false;
  String _errorMessage = '';

  final _riskAssessmentController = RiskAssessmentController(
    HistoricalFloodController(HistoricalFloodService()),
    EnvironmentController(TerrainService(), WeatherService()),
    RiskAssessmentService(),
    FloodSimulationService(),
  );

  Future<void> _submit() async {
    final propertyName = _propertyNameController.text.trim();
    final district = _districtController.text.trim();
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    final userElevation = _elevationController.text.trim().isEmpty
        ? null
        : double.tryParse(_elevationController.text.trim());

    if (propertyName.isEmpty || district.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all required fields');
      return;
    }
    if (latitude == null || longitude == null) {
      setState(() => _errorMessage = 'Latitude/longitude must be numbers');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final outcome = await _riskAssessmentController.runAssessment(
      propertyName: propertyName,
      structureType: _structureType,
      latitude: latitude,
      longitude: longitude,
      state: _state,
      district: district,
      userElevationMeters: userElevation,
      hasFloodBarriers: _hasFloodBarriers,
      hasRaisedFoundation: _hasRaisedFoundation,
    );

    if (!mounted) return;

    if (outcome.error != null || outcome.simulation == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = outcome.error ?? 'Something went wrong';
      });
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.simulationDetail,
      arguments: SimulationDetailArgs(
        simulation: outcome.simulation!,
        factors: outcome.factors,
        recommendations: outcome.recommendations,
      ),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Risk Assessment'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsive(mobile: 20, tablet: 32, desktop: 40),
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.responsive(mobile: 600, tablet: 640),
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

                  const Text(
                    'Property',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _propertyNameController,
                    decoration: _decoration('Property name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _structureType,
                    decoration: _decoration('Structure type'),
                    items: RiskAssessmentService.structureTypeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _structureType = value);
                    },
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Location',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manual entry for now — a map picker is planned for a later task.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _state,
                    decoration: _decoration('State'),
                    items: MalaysiaGeocoder.states
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _state = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _districtController,
                    decoration: _decoration('District', hint: 'e.g. Petaling'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _decoration('Latitude'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _longitudeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _decoration('Longitude'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _elevationController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration(
                      'Elevation override (m, optional)',
                      hint: 'Leave blank to use terrain data automatically',
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Flood Protection',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flood barriers installed'),
                    value: _hasFloodBarriers,
                    onChanged: (value) =>
                        setState(() => _hasFloodBarriers = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Raised foundation'),
                    value: _hasRaisedFoundation,
                    onChanged: (value) =>
                        setState(() => _hasRaisedFoundation = value),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Run Assessment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _propertyNameController.dispose();
    _districtController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _elevationController.dispose();
    super.dispose();
  }
}
