import 'dart:convert';

import 'garment_type.dart';

/// سجل قياس لعميل واحد: بياناته الأساسية + قياسات نوع واحد أو أكثر من الملابس.
class MeasurementRecord {
  final int? id;
  final String fullName;
  final String phone;
  final String notes;
  final Map<GarmentType, Map<String, double>> measurements;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// وقت نقل السجل إلى سلة المحذوفات، أو null إذا كان السجل نشطًا.
  final DateTime? deletedAt;

  const MeasurementRecord({
    this.id,
    required this.fullName,
    required this.phone,
    required this.notes,
    required this.measurements,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  List<GarmentType> get garmentTypes => measurements.keys.toList();

  MeasurementRecord copyWith({
    int? id,
    String? fullName,
    String? phone,
    String? notes,
    Map<GarmentType, Map<String, double>>? measurements,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeasurementRecord(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      measurements: measurements ?? this.measurements,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'phone': phone,
      'notes': notes,
      'measurements': jsonEncode(
        measurements.map((type, values) => MapEntry(type.name, values)),
      ),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory MeasurementRecord.fromMap(Map<String, Object?> map) {
    final rawMeasurements =
        jsonDecode(map['measurements'] as String) as Map<String, dynamic>;
    final measurements = rawMeasurements.map((typeName, values) {
      final valueMap = (values as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
      return MapEntry(GarmentTypeX.fromName(typeName), valueMap);
    });
    return MeasurementRecord(
      id: map['id'] as int?,
      fullName: map['fullName'] as String,
      phone: map['phone'] as String,
      notes: (map['notes'] as String?) ?? '',
      measurements: measurements,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      deletedAt: map['deletedAt'] == null
          ? null
          : DateTime.parse(map['deletedAt'] as String),
    );
  }
}
