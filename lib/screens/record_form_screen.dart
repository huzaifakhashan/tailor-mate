import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database_helper.dart';
import '../models/garment_type.dart';
import '../models/measurement_record.dart';

class RecordFormScreen extends StatefulWidget {
  final MeasurementRecord? record;

  const RecordFormScreen({super.key, this.record});

  bool get isEditing => record != null;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  GarmentType _activeType = GarmentType.kabbiya;

  final Map<GarmentType, Map<String, TextEditingController>> _controllers = {
    for (final type in GarmentType.values) type: {},
  };

  bool _saving = false;
  String? _nameErrorText;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _nameController = TextEditingController(text: record?.fullName ?? '');
    _phoneController = TextEditingController(text: record?.phone ?? '');
    _notesController = TextEditingController(text: record?.notes ?? '');

    for (final type in GarmentType.values) {
      for (final field in type.fields) {
        final value = record?.measurements[type]?[field.key];
        _controllers[type]![field.key] = TextEditingController(
          text: value == null ? '' : _formatNumber(value),
        );
      }
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    for (final fields in _controllers.values) {
      for (final controller in fields.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  /// يفحص كل الأقسام: يجمع الأقسام المكتملة بالكامل، ويرصد أي قسم "منقوص"
  /// (فيه بعض الحقول فقط) لإرجاع خطأ ومنع الحفظ في هذه الحالة.
  ({Map<GarmentType, Map<String, double>> collected, GarmentType? incomplete})
      _collectMeasurements() {
    final collected = <GarmentType, Map<String, double>>{};
    GarmentType? incomplete;

    for (final type in GarmentType.values) {
      final fields = type.fields;
      final values = <String, double>{};
      var filledCount = 0;
      for (final field in fields) {
        final text = _controllers[type]![field.key]!.text.trim();
        if (text.isNotEmpty) {
          filledCount++;
          final parsed = double.tryParse(text);
          if (parsed != null) values[field.key] = parsed;
        }
      }
      if (filledCount == fields.length) {
        collected[type] = values;
      } else if (filledCount > 0) {
        incomplete ??= type;
      }
    }
    return (collected: collected, incomplete: incomplete);
  }

  String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<bool> _isDuplicateName(String name) async {
    final all = await _db.fetchAllRecords();
    return all.any(
      (r) => r.id != widget.record?.id && _normalizeName(r.fullName) == name,
    );
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final normalizedName = _normalizeName(_nameController.text);
    final isDuplicate = await _isDuplicateName(normalizedName);
    if (!mounted) return;
    if (isDuplicate) {
      setState(() {
        _nameErrorText = 'هذا الاسم مسجّل مسبقًا، الرجاء التأكد من الاسم';
      });
      _formKey.currentState?.validate();
      return;
    }

    final result = _collectMeasurements();

    if (result.incomplete != null) {
      setState(() => _activeType = result.incomplete!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'أكمل كل قياسات "${result.incomplete!.label}" أو اترك القسم فارغًا بالكامل',
          ),
        ),
      );
      return;
    }

    if (result.collected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تعبئة قياسات نوع واحد على الأقل من الملابس'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    final record = MeasurementRecord(
      id: widget.record?.id,
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      notes: _notesController.text.trim(),
      measurements: result.collected,
      createdAt: widget.record?.createdAt ?? now,
      updatedAt: now,
    );

    if (widget.isEditing) {
      await _db.updateRecord(record);
    } else {
      await _db.insertRecord(record);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نقل إلى سلة المحذوفات'),
        content: Text(
          'سيتم نقل سجل "${widget.record!.fullName}" إلى سلة المحذوفات، وفيك تستعيدو من فيها في أي وقت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('نقل للمحذوفات'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.softDeleteRecord(widget.record!.id!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'تعديل السجل' : 'عميل جديد'),
        actions: [
          if (widget.isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف السجل',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _SectionTitle('بيانات العميل'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_nameErrorText != null) {
                  setState(() => _nameErrorText = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'الاسم الثلاثي',
                hintText: 'مثال: أحمد محمد علي',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _nameErrorText,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء إدخال اسم العميل';
                }
                return _nameErrorText;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
              ],
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                hintText: '09XXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                if (value.trim().length < 7) {
                  return 'رقم الهاتف غير صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              textDirection: TextDirection.rtl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                hintText: 'أي تفاصيل إضافية...',
                prefixIcon: Icon(Icons.note_alt_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('القياسات (سم)'),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'عبّي قسم لبس واحد على الأقل، وفيك تعبّي أكتر من نوع بنفس الوقت',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _GarmentTabStrip(
              active: _activeType,
              onChanged: (type) => setState(() => _activeType = type),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey(_activeType),
                children: [
                  for (final field in _activeType.fields) ...[
                    _MeasurementInput(
                      field: field,
                      controller: _controllers[_activeType]![field.key]!,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(widget.isEditing ? 'حفظ التعديلات' : 'حفظ السجل'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ),
    );
  }
}

class _GarmentTabStrip extends StatelessWidget {
  final GarmentType active;
  final ValueChanged<GarmentType> onChanged;

  const _GarmentTabStrip({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final type in GarmentType.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: type == active ? colorScheme.surface : null,
                    borderRadius: BorderRadius.circular(10),
                    border: type == active
                        ? Border(
                            bottom: BorderSide(
                              color: colorScheme.primary,
                              width: 2.5,
                            ),
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type.icon,
                        size: 20,
                        color: type == active
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              type == active ? FontWeight.bold : FontWeight.normal,
                          color: type == active
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _MeasurementInput extends StatelessWidget {
  final MeasurementField field;
  final TextEditingController controller;

  const _MeasurementInput({required this.field, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textDirection: TextDirection.rtl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: field.label,
        suffixText: 'سم',
        isDense: true,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        if (double.tryParse(value.trim()) == null) {
          return 'قيمة غير صحيحة';
        }
        return null;
      },
    );
  }
}
