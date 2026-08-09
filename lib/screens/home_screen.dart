import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../data/database_helper.dart';
import '../models/garment_type.dart';
import '../models/measurement_record.dart';
import 'record_form_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  List<MeasurementRecord> _allRecords = [];
  List<MeasurementRecord> _filteredRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    final records = await _db.fetchAllRecords();
    setState(() {
      _allRecords = records;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredRecords = _allRecords;
      } else {
        _filteredRecords = _allRecords.where((r) {
          return r.fullName.contains(query) || r.phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _openForm({MeasurementRecord? record}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecordFormScreen(record: record)),
    );
    if (result == true) {
      _loadRecords();
    }
  }

  Future<void> _confirmDelete(MeasurementRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نقل إلى سلة المحذوفات'),
        content: Text(
          'سيتم نقل سجل "${record.fullName}" إلى سلة المحذوفات، وفيك تستعيدو من فيها في أي وقت.',
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
    if (confirmed == true && record.id != null) {
      await _db.softDeleteRecord(record.id!);
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نقل سجل "${record.fullName}" إلى سلة المحذوفات'),
            action: SnackBarAction(
              label: 'تراجع',
              onPressed: () async {
                await _db.restoreRecord(record.id!);
                _loadRecords();
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قياساتي'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              );
              _loadRecords();
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'سلة المحذوفات',
          ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadRecords();
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                    ? _EmptyState(hasQuery: _searchController.text.isNotEmpty)
                    : RefreshIndicator(
                        onRefresh: _loadRecords,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                          itemCount: _filteredRecords.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final record = _filteredRecords[index];
                            return _RecordCard(
                              record: record,
                              onTap: () => _openForm(record: record),
                              onDelete: () => _confirmDelete(record),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('عميل جديد'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.inventory_2_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'لا توجد نتائج مطابقة' : 'لا توجد سجلات بعد',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (!hasQuery)
              Text(
                'اضغط على زر "عميل جديد" لإضافة أول سجل قياس',
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

class _RecordCard extends StatelessWidget {
  final MeasurementRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    record.garmentTypes.isEmpty
                        ? Icons.person_outline
                        : record.garmentTypes.first.icon,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (record.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          record.phone,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.outline),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final type in record.garmentTypes)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    type.icon,
                                    size: 12,
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    type.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color:
                                              colorScheme.onSecondaryContainer,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            DateFormat('yyyy/MM/dd').format(record.updatedAt),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left, color: colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
