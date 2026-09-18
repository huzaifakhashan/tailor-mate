import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database_helper.dart';
import 'models/garment_type.dart';
import 'models/measurement_record.dart';
import 'screens/home_screen.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseHelper.instance;
  if ((await db.fetchAllRecords()).isEmpty) {
    final now = DateTime.now();
    final demo = <List<Object>>[
      ['أحمد الخطيب', '0991 234 567', GarmentType.kabbiya],
      ['محمد العلي', '0944 111 222', GarmentType.shirt],
      ['خالد السعيد', '0933 456 789', GarmentType.pants],
      ['يوسف الحمصي', '0955 321 654', GarmentType.pajama],
      ['عمر الشامي', '0988 777 888', GarmentType.kabbiya],
    ];
    var i = 0;
    for (final d in demo) {
      final type = d[2] as GarmentType;
      await db.insertRecord(MeasurementRecord(
        fullName: d[0] as String,
        phone: d[1] as String,
        notes: 'عميل تجريبي',
        measurements: {
          type: {for (final f in type.fields) f.key: 40.0 + f.key.length * 3},
        },
        createdAt: now.subtract(Duration(days: i)),
        updatedAt: now.subtract(Duration(days: i++)),
      ));
    }
  }
  runApp(const TailorApp());
}

class TailorApp extends StatefulWidget {
  const TailorApp({super.key});

  @override
  State<TailorApp> createState() => _TailorAppState();
}

class _TailorAppState extends State<TailorApp> {
  final _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.addListener(() => setState(() {}));
    _themeController.load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF1565C0);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ).copyWith(surface: Colors.white);
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeControllerScope(
      controller: _themeController,
      child: MaterialApp(
        title: 'قياساتي',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            scrolledUnderElevation: 1,
            centerTitle: true,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          cardTheme: const CardThemeData(margin: EdgeInsets.zero),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkColorScheme,
          scaffoldBackgroundColor: darkColorScheme.surface,
          appBarTheme: AppBarTheme(
            backgroundColor: darkColorScheme.surface,
            foregroundColor: darkColorScheme.onSurface,
            elevation: 0,
            scrolledUnderElevation: 1,
            centerTitle: true,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkColorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          cardTheme: const CardThemeData(margin: EdgeInsets.zero),
        ),
        themeMode: _themeController.themeMode,
        home: const HomeScreen(),
      ),
    );
  }
}

/// يوفر [ThemeController] لأي شاشة تحته عبر [BuildContext] دون الحاجة لحزمة
/// إدارة حالة خارجية.
class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope not found in context');
    return scope!.notifier!;
  }
}
