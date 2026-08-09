import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/database_helper.dart';
import '../models/garment_type.dart';
import '../models/measurement_record.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final _db = DatabaseHelper.instance;
  List<MeasurementRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await _db.fetchDeletedRecords();
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  String _normalize(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _restore(MeasurementRecord record) async {
    final activeRecords = await _db.fetchAllRecords();
    final normalized = _normalize(record.fullName);
    final conflict = activeRecords.any(
      (r) => _normalize(r.fullName) == normalized,
    );

    String? newName;
    if (conflict) {
      newName = await _promptRename(record.fullName, activeRecords);
      if (newName == null) return;
    }

    await _db.restoreRecord(
      record.id!,
      newFullName: conflict ? newName : null,
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استعادة سجل "${newName ?? record.fullName}"')),
    );
  }

  Future<String?> _promptRename(
    String oldName,
    List<MeasurementRecord> activeRecords,
  ) async {
    final controller = TextEditingController(text: oldName);
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الاسم مستخدم حاليًا'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('يوجد عميل نشط بنفس الاسم "$oldName". عدّل الاسم لإتمام الاستعادة.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                textDirection: TextDirection.rtl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'الاسم الثلاثي الجديد',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'الرجاء إدخال اسم';
                  final normalized = _normalize(trimmed);
                  final stillConflicts = activeRecords.any(
                    (r) => _normalize(r.fullName) == normalized,
                  );
                  if (stillConflicts) return 'هذا الاسم مستخدم أيضًا، جرّب اسمًا آخر';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }

  Future<void> _permanentlyDelete(MeasurementRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نهائي'),
        content: Text(
          'سيتم حذف سجل "${record.fullName}" نهائيًا ولا يمكن التراجع عن هذا الإجراء. متابعة؟',
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
            child: const Text('حذف نهائيًا'),
          ),
        ],
      ),
    );
    if (confirmed == true && record.id != null) {
      await _db.permanentlyDeleteRecord(record.id!);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف سجل "${record.fullName}" نهائيًا')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلة المحذوفات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const _EmptyTrash()
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final record = _records[index];
                return _TrashCard(
                  record: record,
                  onRestore: () => _restore(record),
                  onDeleteForever: () => _permanentlyDelete(record),
                );
              },
            ),
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('سلة المحذوفات فارغة', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'السجلات المحذوفة بتضل هون لحد ما تستعيدها أو تحذفها نهائيًا',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashCard extends StatelessWidget {
  final MeasurementRecord record;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashCard({
    required this.record,
    required this.onRestore,
    required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.errorContainer,
                  child: Icon(
                    record.garmentTypes.isEmpty
                        ? Icons.person_outline
                        : record.garmentTypes.first.icon,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (record.deletedAt != null)
                        Text(
                          'حُذف بتاريخ ${DateFormat('yyyy/MM/dd').format(record.deletedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDeleteForever,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: const Text('حذف نهائي'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('استعادة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
