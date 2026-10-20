import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:angelschein_nrw/data/content_repository.dart';
import 'package:angelschein_nrw/main.dart';
import 'package:angelschein_nrw/services/progress_service.dart';
import 'package:angelschein_nrw/state/app_settings.dart';

/// Supabase is deliberately never initialized here — that is exactly the
/// state a real device is in when the backend can't be reached at startup.
/// The quiz runs entirely on bundled content, so it must still start.
Future<void> _bootIntoHome(WidgetTester tester, {required int germanLevel}) async {
  SharedPreferences.setMockInitialValues({'onboarding_done': true, 'german_level': germanLevel});
  final settings = AppSettings();
  final repository = ContentRepository();
  // Real asset I/O never completes inside testWidgets' fake-async zone.
  await tester.runAsync(() => Future.wait([settings.load(), repository.load()]));

  await tester.pumpWidget(AngelscheinApp(settings: settings, repository: repository, progress: ProgressService()));
  await tester.pumpAndSettle();
}

void main() {
  // The original bug was a tap landing on the bottom bar instead of the
  // start button — a missed hit must fail the test, not just warn.
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('mock exam starts and shows the first of 60 questions without a backend', (tester) async {
    await _bootIntoHome(tester, germanLevel: 1);

    await tester.tap(find.text('Sınav · Prüfung'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SINAVI BAŞLAT · PRÜFUNG STARTEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1/60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category quiz starts and shows its first question without a backend', (tester) async {
    await _bootIntoHome(tester, germanLevel: 1);

    await tester.tap(find.text('Genel Balık Bilgisi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('1/'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('answering a mock exam question reveals feedback and the next button', (tester) async {
    await _bootIntoHome(tester, germanLevel: 1);

    await tester.tap(find.text('Sınav · Prüfung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SINAVI BAŞLAT · PRÜFUNG STARTEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Option badges are the letters a/b/c rendered in upper case.
    await tester.tap(find.text('A').first);
    await tester.pump();

    expect(find.text('İLERİ · WEITER'), findsOneWidget);
    await tester.tap(find.text('İLERİ · WEITER'));
    await tester.pump();
    expect(find.text('2/60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  void useSmallPhone(WidgetTester tester, {double textScale = 1.0}) {
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  for (final textScale in [1.0, 1.3, 2.0]) {
    testWidgets('every tab fits a small phone at text scale $textScale', (tester) async {
      useSmallPhone(tester, textScale: textScale);
      await _bootIntoHome(tester, germanLevel: 2);
      for (final tab in ['Sınav · Prüfung', 'Sözlük · Wörterbuch', 'Ayarlar · Einstellungen', 'Kategoriler · Kategorien']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'overflow/exception on "$tab"');
      }
    });
  }

  testWidgets('start button is reachable and starts the exam on a small phone', (tester) async {
    useSmallPhone(tester, textScale: 1.3);
    await _bootIntoHome(tester, germanLevel: 2);

    await tester.tap(find.text('Sınav · Prüfung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SINAVI BAŞLAT · PRÜFUNG STARTEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1/60'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
