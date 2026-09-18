import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/theme_controller.dart';

void main() {
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
