import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_settings.dart';

/// App-chrome text (nav labels, headers, buttons, section titles — anything
/// that isn't the quiz question/answer reveal, which has its own dedicated
/// DE-then-TR mechanic). "Almanca biliyorum" shows German only everywhere;
/// the other two levels show Turkish and German together.
extension AppLocalization on BuildContext {
  String ui({required String tr, required String de}) {
    final fluent = watch<AppSettings>().germanLevel == GermanLevel.fluent;
    return fluent ? de : '$tr · $de';
  }

  /// Same as [ui] but does not subscribe to rebuilds — for one-off reads
  /// (e.g. inside a dialog already built from a snapshot of the level).
  String uiRead({required String tr, required String de}) {
    final fluent = read<AppSettings>().germanLevel == GermanLevel.fluent;
    return fluent ? de : '$tr · $de';
  }

  bool get isFluentGerman => watch<AppSettings>().germanLevel == GermanLevel.fluent;
}
