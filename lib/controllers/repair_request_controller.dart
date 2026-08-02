import 'package:image_picker/image_picker.dart';

import '../models/repair_request.dart';
import '../services/repair_request_service.dart';

class RepairRequestController {
  final RepairRequestService repairRequestService;

  RepairRequestController(this.repairRequestService);

  Future<bool> submit(RepairRequest request, List<XFile> photos) {
    return repairRequestService.submit(request, photos);
  }
}
