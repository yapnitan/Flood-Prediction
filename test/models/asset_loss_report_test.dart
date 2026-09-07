import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/models/asset_loss_report.dart';

Map<String, dynamic> _row({
  String status = 'pending_review',
  num? verifiedTotalLoss,
  num? approvedTotalLoss,
}) {
  return {
    'id': 'report-1',
    'user_id': 'user-1',
    'property_id': 42,
    'flood_incident_id': null,
    'asset_category': 'Appliances',
    'asset_name': 'Refrigerator',
    'condition': 'completely_destroyed',
    'quantity': 2,
    'estimated_value_per_item': 1500.0,
    'estimated_total_loss': 3000.0,
    'description': 'Flooded kitchen',
    'photo_paths': ['user-1/report-1/photo_0.jpg'],
    'status': status,
    'verified_quantity': verifiedTotalLoss == null ? null : 2,
    'verified_value_per_item': verifiedTotalLoss == null ? null : 1300.0,
    'verified_total_loss': verifiedTotalLoss,
    'approved_quantity': approvedTotalLoss == null ? null : 2,
    'approved_value_per_item': approvedTotalLoss == null ? null : 1200.0,
    'approved_total_loss': approvedTotalLoss,
  };
}

void main() {
  group('AssetLossReport.fromJson', () {
    test('parses a pending report round-trip', () {
      final report = AssetLossReport.fromJson(_row());

      expect(report.id, 'report-1');
      expect(report.propertyId, 42);
      expect(report.assetCategory, 'Appliances');
      expect(report.quantity, 2);
      expect(report.estimatedValuePerItem, 1500.0);
      expect(report.estimatedTotalLoss, 3000.0);
      expect(report.photoPaths, ['user-1/report-1/photo_0.jpg']);
      expect(report.verifiedQuantity, isNull);
      expect(report.approvedTotalLoss, isNull);
    });

    test('parses helper-verified and admin-approved figures once present', () {
      final report = AssetLossReport.fromJson(_row(
        status: 'verified',
        verifiedTotalLoss: 2600.0,
        approvedTotalLoss: 2400.0,
      ));

      expect(report.verifiedTotalLoss, 2600.0);
      expect(report.approvedTotalLoss, 2400.0);
    });

    test('missing photo_paths defaults to an empty list', () {
      final row = _row()..remove('photo_paths');
      final report = AssetLossReport.fromJson(row);

      expect(report.photoPaths, isEmpty);
    });
  });

  group('AssetLossReport status getters', () {
    test('isPending/isVerified/isRejected reflect the status field exactly', () {
      expect(AssetLossReport.fromJson(_row(status: 'pending_review')).isPending, isTrue);
      expect(AssetLossReport.fromJson(_row(status: 'verified')).isVerified, isTrue);
      expect(AssetLossReport.fromJson(_row(status: 'rejected')).isRejected, isTrue);
      expect(AssetLossReport.fromJson(_row(status: 'verified')).isPending, isFalse);
    });
  });

  group('AssetLossReport.toJson', () {
    test('submission payload never includes server-computed or review fields', () {
      final report = AssetLossReport.fromJson(_row(status: 'verified', approvedTotalLoss: 2400.0));
      final json = report.toJson();

      expect(json['property_id'], 42);
      expect(json['asset_category'], 'Appliances');
      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('approved_total_loss'), isFalse);
      expect(json.containsKey('estimated_total_loss'), isFalse);
    });
  });
}
