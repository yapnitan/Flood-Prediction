import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/flood_simulation.dart';
import '../../models/property.dart';
import '../../controllers/property_controller.dart';
import '../../controllers/risk_assessment_controller.dart';
import '../../controllers/historical_flood_controller.dart';
import '../../controllers/environment_controller.dart';
import '../../services/historical_flood_service.dart';
import '../../services/property_service.dart';
import '../../services/terrain_service.dart';
import '../../services/weather_service.dart';
import '../../services/risk_assessment_service.dart';
import '../../services/flood_simulation_service.dart';
import '../../utils/responsive.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_arguments.dart';
import '../../services/notification_service.dart';
import 'property_form_view.dart';

class CreateSimulationView extends StatefulWidget {

  final FloodSimulation? existing;

  const CreateSimulationView({super.key, this.existing});

  @override
  State<CreateSimulationView> createState() => _CreateSimulationViewState();
}

class _CreateSimulationViewState extends State<CreateSimulationView> {
  final _elevationController = TextEditingController();

  final _propertyController = PropertyController(PropertyService());
  final _riskAssessmentController = RiskAssessmentController(
    HistoricalFloodController(HistoricalFloodService()),
    EnvironmentController(TerrainService(), WeatherService()),
    RiskAssessmentService(),
    FloodSimulationService(),
  );

  List<Property> _myProperties = [];
  Property? _selectedProperty;
  bool _isLoadingProperties = true;

  late String _structureType;
  late bool _hasFloodBarriers;
  late bool _hasRaisedFoundation;

  bool _isSubmitting = false;
  String _errorMessage = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _elevationController.text = existing?.userElevationMeters?.toString() ?? '';
    _structureType =
        existing?.structureType ??
        RiskAssessmentService.structureTypeOptions.first;
    _hasFloodBarriers = existing?.hasFloodBarriers ?? false;
    _hasRaisedFoundation = existing?.hasRaisedFoundation ?? false;
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    final properties = await _propertyController.getMyProperties();
    if (!mounted) return;

    final existingPropertyId = widget.existing?.propertyId;
    Property? selected;
    for (final p in properties) {
      if (existingPropertyId != null && p.id == existingPropertyId) selected = p;
    }
    selected ??= existingPropertyId == null && properties.isNotEmpty
        ? properties.first
        : null;

    setState(() {
      _myProperties = properties;
      _selectedProperty = selected;
      _isLoadingProperties = false;
    });
  }

  Future<void> _addAddress() async {
    final created = await Navigator.push<Property>(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFormView(controller: _propertyController),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _myProperties = [created, ..._myProperties];
      _selectedProperty = created;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final property = _selectedProperty;
    if (property == null) {
      setState(() => _errorMessage = 'Select the address to assess.');
      return;
    }
    final state = property.state?.trim() ?? '';
    final district = property.district?.trim() ?? '';
    if (state.isEmpty || district.isEmpty) {
      setState(
        () => _errorMessage =
            'This address is missing its state or district — edit the address '
            'and add them before running an assessment.',
      );
      return;
    }
    final userElevation = _elevationController.text.trim().isEmpty
        ? null
        : double.tryParse(_elevationController.text.trim());

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final propertyName = property.label?.trim().isNotEmpty == true
        ? property.label!.trim()
        : (property.address?.trim().isNotEmpty == true
              ? property.address!.trim()
              : property.displayLabel);

    final existingId = widget.existing?.id;
    final outcome = existingId != null
        ? await _riskAssessmentController.updateAssessment(
            simulationId: existingId,
            propertyId: property.id,
            propertyName: propertyName,
            structureType: _structureType,
            latitude: property.lat,
            longitude: property.lng,
            state: state,
            district: district,
            userElevationMeters: userElevation,
            hasFloodBarriers: _hasFloodBarriers,
            hasRaisedFoundation: _hasRaisedFoundation,
          )
        : await _riskAssessmentController.runAssessment(
            propertyId: property.id,
            propertyName: propertyName,
            structureType: _structureType,
            latitude: property.lat,
            longitude: property.lng,
            state: state,
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

    unawaited(
      NotificationService.instance.showNow(
        id: NotificationService.idSimulationCompletion,
        title: _isEditing ? 'Assessment updated' : 'Risk assessment complete',
        body:
            '${outcome.simulation!.propertyName}: ${outcome.simulation!.riskLevel} risk (${outcome.simulation!.riskScore.toStringAsFixed(0)}/100).',
      ),
    );

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
    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Edit Risk Assessment' : 'New Risk Assessment',
          ),
        ),
        body: SafeArea(
          child: _isLoadingProperties
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.responsive(
                      mobile: 20,
                      tablet: 32,
                      desktop: 40,
                    ),
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
                            'Address',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pick one of your saved addresses — the assessment '
                            'uses its saved location.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),

                          if (_myProperties.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                'You have no saved addresses yet. Add one to '
                                'run a flood risk assessment for it.',
                                style: TextStyle(fontSize: 13),
                              ),
                            )
                          else
                            ..._myProperties.map(
                              (property) => RadioListTile<int>(
                                value: property.id!,
                                // ignore: deprecated_member_use
                                groupValue: _selectedProperty?.id,
                                // ignore: deprecated_member_use
                                onChanged: (value) => setState(
                                  () => _selectedProperty = _myProperties
                                      .firstWhere((p) => p.id == value),
                                ),
                                title: Text(property.displayLabel),
                                subtitle:
                                    (property.district ?? '').isNotEmpty
                                    ? Text(
                                        '${property.district}, ${property.state}',
                                      )
                                    : const Text(
                                        'Missing state/district — edit this address',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _addAddress,
                            icon: const Icon(Icons.add),
                            label: const Text('Add another address'),
                          ),

                          const SizedBox(height: 24),
                          const Text(
                            'Property details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _structureType,
                            decoration: _decoration('Structure type'),
                            items: RiskAssessmentService.structureTypeOptions
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _structureType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _elevationController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _decoration(
                              'Elevation override (m, optional)',
                              hint:
                                  'Leave blank to use terrain data automatically',
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Text(
                            'Flood Protection',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
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
                                      _isEditing
                                          ? 'Update Assessment'
                                          : 'Run Assessment',
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
      ),
    );
  }

  @override
  void dispose() {
    _elevationController.dispose();
    super.dispose();
  }
}
