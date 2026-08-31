import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GermanLevel { fluent, little, none }

const _kGermanLevel = 'german_level';
const _kThemeMode = 'theme_mode';
const _kOnboardingDone = 'onboarding_done';

class AppSettings extends ChangeNotifier {
  GermanLevel _germanLevel = GermanLevel.little;
  ThemeMode _themeMode = ThemeMode.light;
  bool _onboardingDone = false;
  bool _loaded = false;

  GermanLevel get germanLevel => _germanLevel;

  /// Derived, not a separate setting: only "Almanca biliyorum" runs fully in
  /// German. Every other level shows the German-then-Turkish reveal.
  bool get dualLanguageMode => _germanLevel != GermanLevel.fluent;

  ThemeMode get themeMode => _themeMode;
  bool get onboardingDone => _onboardingDone;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final levelIndex = prefs.getInt(_kGermanLevel);
    if (levelIndex != null && levelIndex < GermanLevel.values.length) {
      _germanLevel = GermanLevel.values[levelIndex];
    }
    final themeIndex = prefs.getInt(_kThemeMode);
    if (themeIndex != null && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    _onboardingDone = prefs.getBool(_kOnboardingDone) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding(GermanLevel level) async {
    _germanLevel = level;
    _onboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGermanLevel, level.index);
    await prefs.setBool(_kOnboardingDone, true);
    notifyListeners();
  }

  Future<void> setGermanLevel(GermanLevel level) async {
    _germanLevel = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGermanLevel, level.index);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }
}
