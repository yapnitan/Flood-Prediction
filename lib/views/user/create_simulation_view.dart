import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/flood_simulation.dart';
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
import '../../services/notification_service.dart';
import 'pick_property_location_view.dart';

class CreateSimulationView extends StatefulWidget {
  /// When set, the form opens pre-filled to edit this simulation instead
  /// of starting a fresh assessment.
  final FloodSimulation? existing;

  const CreateSimulationView({super.key, this.existing});

  @override
  State<CreateSimulationView> createState() => _CreateSimulationViewState();
}

class _CreateSimulationViewState extends State<CreateSimulationView> {
  final _propertyNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _elevationController = TextEditingController();

  late String _structureType;
  late String _state;
  late bool _hasFloodBarriers;
  late bool _hasRaisedFoundation;

  bool _isSubmitting = false;
  String _errorMessage = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _propertyNameController.text = existing?.propertyName ?? '';
    _districtController.text = existing?.district ?? '';
    _latitudeController.text = existing?.latitude.toStringAsFixed(6) ?? '';
    _longitudeController.text = existing?.longitude.toStringAsFixed(6) ?? '';
    _elevationController.text = existing?.userElevationMeters?.toString() ?? '';
    _structureType = existing?.structureType ?? RiskAssessmentService.structureTypeOptions.first;
    _state = existing?.state ?? MalaysiaGeocoder.states.first;
    _hasFloodBarriers = existing?.hasFloodBarriers ?? false;
    _hasRaisedFoundation = existing?.hasRaisedFoundation ?? false;
  }

  Future<void> _pickLocationOnMap() async {
    final current = double.tryParse(_latitudeController.text.trim());
    final currentLng = double.tryParse(_longitudeController.text.trim());
    final initial = (current != null && currentLng != null)
        ? LatLng(current, currentLng)
        : null;

    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => PickPropertyLocationView(initialLocation: initial),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _latitudeController.text = picked.latitude.toStringAsFixed(6);
      _longitudeController.text = picked.longitude.toStringAsFixed(6);
    });
  }

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

    final existingId = widget.existing?.id;
    final outcome = existingId != null
        ? await _riskAssessmentController.updateAssessment(
            simulationId: existingId,
            propertyName: propertyName,
            structureType: _structureType,
            latitude: latitude,
            longitude: longitude,
            state: _state,
            district: district,
            userElevationMeters: userElevation,
            hasFloodBarriers: _hasFloodBarriers,
            hasRaisedFoundation: _hasRaisedFoundation,
          )
        : await _riskAssessmentController.runAssessment(
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

    // Task 12 "simulation completion" notification — fired here rather
    // than waited-on, so it doesn't delay navigating to the result.
    unawaited(NotificationService.instance.showNow(
      id: NotificationService.idSimulationCompletion,
      title: _isEditing ? 'Assessment updated' : 'Risk assessment complete',
      body:
          '${outcome.simulation!.propertyName}: ${outcome.simulation!.riskLevel} risk (${outcome.simulation!.riskScore.toStringAsFixed(0)}/100).',
    ));

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
        title: Text(_isEditing ? 'Edit Risk Assessment' : 'New Risk Assessment'),
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
                    'Pick the property on the map, or enter coordinates manually below.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickLocationOnMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Pick location on map'),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                          : Text(
                              _isEditing ? 'Update Assessment' : 'Run Assessment',
                              style: const TextStyle(
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
