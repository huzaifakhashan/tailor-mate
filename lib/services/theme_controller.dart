import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يتحكم بوضع المظهر (فاتح/داكن) ويحفظ اختيار المستخدم على الجهاز.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, isDark ? 'dark' : 'light');
  }
}
