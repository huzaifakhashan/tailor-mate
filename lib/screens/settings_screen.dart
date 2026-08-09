import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../main.dart';
import '../services/excel_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final active = await _db.fetchAllRecords();
      final deleted = await _db.fetchDeletedRecords();
      final records = [...active, ...deleted];
      if (records.isEmpty) {
        _showMessage('لا توجد سجلات لتصديرها بعد');
        return;
      }
      final path = await ExcelService.exportToFile(records);
      if (path != null) {
        _showMessage('تم حفظ الملف بنجاح');
      }
    } catch (_) {
      _showMessage('حدث خطأ أثناء التصدير');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final result = await ExcelService.importFromFile(_db);
      if (result == null) return;
      _showMessage(
        'تم استيراد ${result.imported} سجل'
        '${result.skippedDuplicates > 0 ? '، وتجاهل ${result.skippedDuplicates} مكرر' : ''}'
        '${result.skippedInvalid > 0 ? '، وتجاهل ${result.skippedInvalid} غير صالح' : ''}',
      );
    } catch (_) {
      _showMessage('حدث خطأ أثناء الاستيراد، تأكد أن الملف بالتنسيق الصحيح');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.of(context);
    final isDark = themeController.themeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle('المظهر'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  value: isDark,
                  onChanged: (value) => themeController.setDarkMode(value),
                  secondary: Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  ),
                  title: const Text('الوضع الداكن'),
                  subtitle: Text(isDark ? 'مفعّل' : 'الوضع الفاتح مفعّل'),
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle('النسخ الاحتياطي'),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.file_upload_outlined),
                      title: const Text('تصدير البيانات إلى إكسل'),
                      subtitle: const Text('احفظ نسخة من كل سجلات العملاء'),
                      onTap: _busy ? null : _export,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: const Text('استيراد البيانات من إكسل'),
                      subtitle: const Text(
                        'إضافة سجلات من ملف إكسل (يتم تجاهل الأسماء المكررة)',
                      ),
                      onTap: _busy ? null : _import,
                    ),
                  ],
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
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
