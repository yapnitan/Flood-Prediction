class AssetLossReport {
  const AssetLossReport({
    this.id,
    this.userId,
    required this.propertyId,
    this.floodIncidentId,
    required this.assetCategory,
    required this.assetName,
    required this.condition,
    required this.quantity,
    required this.estimatedValuePerItem,
    this.estimatedTotalLoss,
    this.description,
    this.photoPaths = const [],
    this.status = 'pending_review',
    this.verifiedQuantity,
    this.verifiedValuePerItem,
    this.verifiedTotalLoss,
    this.verifiedCondition,
    this.verificationResult,
    this.verificationNotes,
    this.verificationPhotoPaths = const [],
    this.verifiedBy,
    this.verifiedAt,
    this.approvedQuantity,
    this.approvedValuePerItem,
    this.approvedTotalLoss,
    this.reviewedAt,
    this.reviewedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? userId;
  final int propertyId;
  final String? floodIncidentId;

  final String assetCategory;
  final String assetName;
  final String condition;
  final int quantity;
  final double estimatedValuePerItem;
  final double? estimatedTotalLoss;
  final String? description;
  final List<String> photoPaths;

  final String status;

  final int? verifiedQuantity;
  final double? verifiedValuePerItem;
  final double? verifiedTotalLoss;
  final String? verifiedCondition;
  final String? verificationResult;
  final String? verificationNotes;
  final List<String> verificationPhotoPaths;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  final int? approvedQuantity;
  final double? approvedValuePerItem;
  final double? approvedTotalLoss;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AssetLossReport.fromJson(Map<String, dynamic> json) => AssetLossReport(
    id: json['id'] as String?,
    userId: json['user_id'] as String?,
    propertyId: json['property_id'] as int,
    floodIncidentId: json['flood_incident_id'] as String?,
    assetCategory: json['asset_category'] as String,
    assetName: json['asset_name'] as String,
    condition: json['condition'] as String,
    quantity: json['quantity'] as int,
    estimatedValuePerItem: (json['estimated_value_per_item'] as num).toDouble(),
    estimatedTotalLoss: (json['estimated_total_loss'] as num?)?.toDouble(),
    description: json['description'] as String?,
    photoPaths: (json['photo_paths'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    status: json['status'] as String? ?? 'pending_review',
    verifiedQuantity: json['verified_quantity'] as int?,
    verifiedValuePerItem: (json['verified_value_per_item'] as num?)?.toDouble(),
    verifiedTotalLoss: (json['verified_total_loss'] as num?)?.toDouble(),
    verifiedCondition: json['verified_condition'] as String?,
    verificationResult: json['verification_result'] as String?,
    verificationNotes: json['verification_notes'] as String?,
    verificationPhotoPaths: (json['verification_photo_paths'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
    verifiedBy: json['verified_by'] as String?,
    verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at'] as String) : null,
    approvedQuantity: json['approved_quantity'] as int?,
    approvedValuePerItem: (json['approved_value_per_item'] as num?)?.toDouble(),
    approvedTotalLoss: (json['approved_total_loss'] as num?)?.toDouble(),
    reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
    reviewedBy: json['reviewed_by'] as String?,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
  );

  /// For submission — server computes `estimated_total_loss` and defaults
  /// `status`, `id`, timestamps.
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'property_id': propertyId,
    'flood_incident_id': floodIncidentId,
    'asset_category': assetCategory,
    'asset_name': assetName,
    'condition': condition,
    'quantity': quantity,
    'estimated_value_per_item': estimatedValuePerItem,
    'description': description,
    'photo_paths': photoPaths,
  };

  bool get isPending => status == 'pending_review';
  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';
}
