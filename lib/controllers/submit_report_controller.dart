import 'package:image_picker/image_picker.dart';

import '../services/flood_report_service.dart';
import '../services/location_service.dart';

class SubmitReportController {

  final FloodReportService floodReportService;
  final LocationService locationService;
  int currentStep = 1;
  String? selectedFloodType = "Street Flooding";
  String? selectedWaterLevel = "Medium";
  double? selectedLatitude;
  double? selectedLongitude;
  bool isSubmitting = false;
  bool isSubmitted = false;
  DateTime? observedAt;
  List<XFile> photos = [];

  SubmitReportController({
    required this.floodReportService,
    required this.locationService,
  });

}