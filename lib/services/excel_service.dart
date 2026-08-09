import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/database_helper.dart';
import '../models/garment_type.dart';
import '../models/measurement_record.dart';

class ExcelImportResult {
  final int imported;
  final int skippedDuplicates;
  final int skippedInvalid;

  const ExcelImportResult({
    required this.imported,
    required this.skippedDuplicates,
    required this.skippedInvalid,
  });
}

/// يتولى تصدير بيانات العملاء إلى ملف إكسل واستيرادها منه، بحيث يمكن أخذ
/// نسخة احتياطية من قاعدة البيانات المحلية أو نقلها لجهاز آخر.
class ExcelService {
  ExcelService._();

  static const _sheetName = 'العملاء';
  static const _statusActive = 'نشط';
  static const _statusDeleted = 'محذوف';
  static const _metaHeaders = [
    'الاسم الثلاثي',
    'رقم الهاتف',
    'ملاحظات',
    'الحالة',
    'تاريخ الحذف',
    'تاريخ الإضافة',
    'تاريخ آخر تعديل',
  ];

  static String _measurementHeader(GarmentType type, MeasurementField field) {
    return '${type.label} - ${field.label}';
  }

  static List<String> _allHeaders() {
    final headers = [..._metaHeaders];
    for (final type in GarmentType.values) {
      for (final field in type.fields) {
        headers.add(_measurementHeader(type, field));
      }
    }
    return headers;
  }

  static String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static Uint8List _buildWorkbookBytes(List<MeasurementRecord> records) {
    final workbook = Excel.createExcel();
    final sheet = workbook[_sheetName];
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != _sheetName) {
      workbook.delete(defaultSheet);
    }

    sheet.appendRow(_allHeaders().map((h) => TextCellValue(h)).toList());

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    for (final record in records) {
      final row = <CellValue?>[
        TextCellValue(record.fullName),
        TextCellValue(record.phone),
        TextCellValue(record.notes),
        TextCellValue(record.isDeleted ? _statusDeleted : _statusActive),
        TextCellValue(
          record.deletedAt == null ? '' : dateFormat.format(record.deletedAt!),
        ),
        TextCellValue(dateFormat.format(record.createdAt)),
        TextCellValue(dateFormat.format(record.updatedAt)),
      ];
      for (final type in GarmentType.values) {
        for (final field in type.fields) {
          final value = record.measurements[type]?[field.key];
          row.add(value == null ? null : DoubleCellValue(value));
        }
      }
      sheet.appendRow(row);
    }

    return Uint8List.fromList(workbook.encode()!);
  }

  /// يبني ملف الإكسل ويطلب من المستخدم اختيار مكان حفظه على الجهاز.
  /// يعيد المسار عند النجاح، أو null إذا ألغى المستخدم العملية.
  static Future<String?> exportToFile(List<MeasurementRecord> records) async {
    final bytes = _buildWorkbookBytes(records);
    final fileName =
        'قياسات_العملاء_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
  }

  /// يطلب من المستخدم اختيار ملف إكسل ويستورد منه السجلات إلى قاعدة البيانات،
  /// متجاهلاً أي اسم مكرر مع سجل موجود مسبقًا. يعيد null إذا ألغى المستخدم
  /// اختيار الملف.
  static Future<ExcelImportResult?> importFromFile(DatabaseHelper db) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final bytes = picked.files.first.bytes;
    if (bytes == null) return null;

    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      return const ExcelImportResult(
        imported: 0,
        skippedDuplicates: 0,
        skippedInvalid: 0,
      );
    }

    final rows = workbook.tables[workbook.tables.keys.first]!.rows;
    if (rows.isEmpty) {
      return const ExcelImportResult(
        imported: 0,
        skippedDuplicates: 0,
        skippedInvalid: 0,
      );
    }

    final headerIndex = <String, int>{};
    for (var i = 0; i < rows.first.length; i++) {
      final value = rows.first[i]?.value;
      if (value != null) headerIndex[value.toString().trim()] = i;
    }

    final measurementColumns = <GarmentType, Map<String, int>>{};
    for (final type in GarmentType.values) {
      final columns = <String, int>{};
      for (final field in type.fields) {
        final header = _measurementHeader(type, field);
        if (headerIndex.containsKey(header)) {
          columns[field.key] = headerIndex[header]!;
        }
      }
      measurementColumns[type] = columns;
    }

    String cellText(List<Data?> row, int? index) {
      if (index == null || index >= row.length) return '';
      return row[index]?.value?.toString().trim() ?? '';
    }

    final existingNames = (await db.fetchAllRecords())
        .map((r) => _normalizeName(r.fullName))
        .toSet();

    var imported = 0;
    var skippedDuplicates = 0;
    var skippedInvalid = 0;

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (final row in rows.skip(1)) {
      final fullName = cellText(row, headerIndex['الاسم الثلاثي']);
      if (fullName.isEmpty) {
        skippedInvalid++;
        continue;
      }

      final isDeletedRow =
          cellText(row, headerIndex['الحالة']) == _statusDeleted;

      final normalized = _normalizeName(fullName);
      if (!isDeletedRow && existingNames.contains(normalized)) {
        skippedDuplicates++;
        continue;
      }

      final measurements = <GarmentType, Map<String, double>>{};
      for (final type in GarmentType.values) {
        final columns = measurementColumns[type]!;
        if (columns.isEmpty) continue;
        final values = <String, double>{};
        for (final entry in columns.entries) {
          final text = cellText(row, entry.value);
          if (text.isEmpty) continue;
          final parsed = double.tryParse(text);
          if (parsed != null) values[entry.key] = parsed;
        }
        if (values.length == type.fields.length) {
          measurements[type] = values;
        }
      }

      if (measurements.isEmpty) {
        skippedInvalid++;
        continue;
      }

      final now = DateTime.now();
      DateTime? deletedAt;
      if (isDeletedRow) {
        final deletedAtText = cellText(row, headerIndex['تاريخ الحذف']);
        deletedAt = deletedAtText.isEmpty
            ? now
            : (dateFormat.tryParse(deletedAtText) ?? now);
      }

      await db.insertRecord(
        MeasurementRecord(
          fullName: fullName,
          phone: cellText(row, headerIndex['رقم الهاتف']),
          notes: cellText(row, headerIndex['ملاحظات']),
          measurements: measurements,
          createdAt: now,
          updatedAt: now,
          deletedAt: deletedAt,
        ),
      );
      if (!isDeletedRow) existingNames.add(normalized);
      imported++;
    }

    return ExcelImportResult(
      imported: imported,
      skippedDuplicates: skippedDuplicates,
      skippedInvalid: skippedInvalid,
    );
  }
}
