import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/models/repair_request.dart';

RepairRequest _request({
  String priority = 'medium',
  DateTime? createdAt,
  String assistanceType = 'Structural Repair',
  Map<String, dynamic> details = const {},
}) {
  return RepairRequest(
    locationName: 'Test location',
    latitude: 3.1390,
    longitude: 101.6869,
    assistanceType: assistanceType,
    priority: priority,
    createdAt: createdAt,
    details: details,
  );
}

void main() {
  group('RepairRequest.comparePriority', () {
    test('urgent sorts before high, medium, and low', () {
      final list = [
        _request(priority: 'low'),
        _request(priority: 'urgent'),
        _request(priority: 'medium'),
        _request(priority: 'high'),
      ]..sort(RepairRequest.comparePriority);

      expect(list.map((r) => r.priority).toList(), ['urgent', 'high', 'medium', 'low']);
    });

    test('within the same priority, newer requests sort first', () {
      final older = _request(priority: 'high', createdAt: DateTime(2026, 1, 1));
      final newer = _request(priority: 'high', createdAt: DateTime(2026, 6, 1));
      final list = [older, newer]..sort(RepairRequest.comparePriority);

      expect(list.first, newer);
    });

    test('an unrecognized priority value sorts after every known priority', () {
      final list = [
        _request(priority: 'unknown'),
        _request(priority: 'low'),
      ]..sort(RepairRequest.comparePriority);

      expect(list.last.priority, 'unknown');
    });
  });

  group('RepairRequest.suggestedPriority', () {
    test('Medical Assistance suggests urgent', () {
      expect(RepairRequest.suggestedPriority('Medical Assistance'), 'urgent');
    });

    test('Financial Aid suggests low', () {
      expect(RepairRequest.suggestedPriority('Financial Aid'), 'low');
    });

    test('an unrecognized assistance type defaults to medium', () {
      expect(RepairRequest.suggestedPriority('Something else'), 'medium');
    });
  });

  group('RepairRequest.fulfillmentModeFor', () {
    test('Temporary Shelter and Food & Water Supply route through a facility', () {
      expect(RepairRequest.fulfillmentModeFor('Temporary Shelter'), FulfillmentMode.facility);
      expect(RepairRequest.fulfillmentModeFor('Food & Water Supply'), FulfillmentMode.facility);
    });

    test('Financial Aid is remote — nobody travels', () {
      expect(RepairRequest.fulfillmentModeFor('Financial Aid'), FulfillmentMode.remote);
    });

    test('Structural Repair and Medical Assistance are field visits', () {
      expect(RepairRequest.fulfillmentModeFor('Structural Repair'), FulfillmentMode.field);
      expect(RepairRequest.fulfillmentModeFor('Medical Assistance'), FulfillmentMode.field);
    });
  });

  group('RepairRequest.isCriticalMedical', () {
    test('true only for Medical Assistance with is_critical flagged', () {
      final critical = _request(assistanceType: 'Medical Assistance', details: {'is_critical': true});
      final nonCritical = _request(assistanceType: 'Medical Assistance', details: {'is_critical': false});
      final otherType = _request(assistanceType: 'Structural Repair', details: {'is_critical': true});

      expect(critical.isCriticalMedical, isTrue);
      expect(nonCritical.isCriticalMedical, isFalse);
      expect(otherType.isCriticalMedical, isFalse);
    });
  });
}
