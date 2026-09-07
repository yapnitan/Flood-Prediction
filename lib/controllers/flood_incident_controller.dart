import '../models/flood_incident.dart';
import '../services/flood_incident_service.dart';

class FloodIncidentController {
  final FloodIncidentService service;

  FloodIncidentController(this.service);

  Future<List<FloodIncident>> getAll() => service.getAll();

  Future<List<FloodIncident>> getActive() => service.getActive();

  Future<bool> create(FloodIncident incident) => service.create(incident);

  Future<void> close(String id) => service.close(id);
}
