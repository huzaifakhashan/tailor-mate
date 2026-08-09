import 'package:flutter/material.dart';

/// أنواع الملابس المدعومة في التطبيق.
enum GarmentType { kabbiya, shirt, pants, pajama }

/// وصف حقول القياس الخاصة بكل نوع لبس (المفتاح الداخلي وتسميته بالعربي).
class MeasurementField {
  final String key;
  final String label;

  const MeasurementField(this.key, this.label);
}

extension GarmentTypeX on GarmentType {
  String get label {
    switch (this) {
      case GarmentType.kabbiya:
        return 'كلابية';
      case GarmentType.shirt:
        return 'قميص';
      case GarmentType.pants:
        return 'بنطلون';
      case GarmentType.pajama:
        return 'بيجامة';
    }
  }

  IconData get icon {
    switch (this) {
      case GarmentType.kabbiya:
        return Icons.checkroom_rounded;
      case GarmentType.shirt:
        return Icons.dry_cleaning_rounded;
      case GarmentType.pants:
        return Icons.straighten_rounded;
      case GarmentType.pajama:
        return Icons.bedtime_rounded;
    }
  }

  /// حقول القياس المطلوبة لهذا النوع، بالترتيب الذي تظهر فيه بالنموذج.
  List<MeasurementField> get fields {
    switch (this) {
      case GarmentType.kabbiya:
        return const [
          MeasurementField('shoulder', 'الكتف'),
          MeasurementField('length', 'الطول'),
          MeasurementField('sleeve', 'الكم'),
          MeasurementField('waist', 'الخصر'),
          MeasurementField('collar', 'الياقة'),
        ];
      case GarmentType.shirt:
        return const [
          MeasurementField('shoulder', 'الكتف'),
          MeasurementField('length', 'الطول'),
          MeasurementField('waist', 'الخصر'),
          MeasurementField('collar', 'الياقة'),
        ];
      case GarmentType.pants:
        return const [
          MeasurementField('waist', 'الخصر'),
          MeasurementField('length', 'الطول'),
          MeasurementField('kneeSaddle', 'سرج الركبة'),
          MeasurementField('legOpening', 'الحجل'),
        ];
      case GarmentType.pajama:
        return const [
          MeasurementField('waist', 'الخصر'),
          MeasurementField('length', 'الطول'),
          MeasurementField('legOpening', 'الحجل'),
        ];
    }
  }

  static GarmentType fromName(String name) {
    return GarmentType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => GarmentType.kabbiya,
    );
  }
}
