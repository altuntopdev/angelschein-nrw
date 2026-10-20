import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:angelschein_nrw/data/content_repository.dart';
import 'package:angelschein_nrw/main.dart';
import 'package:angelschein_nrw/services/progress_service.dart';
import 'package:angelschein_nrw/state/app_settings.dart';

void main() {
  testWidgets('app boots to onboarding screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    final repository = ContentRepository();
    // Real asset I/O never completes inside testWidgets' fake-async zone.
    await tester.runAsync(() => repository.load());

    await tester.pumpWidget(AngelscheinApp(settings: settings, repository: repository, progress: ProgressService()));
    await tester.pumpAndSettle();

    expect(find.text('Merhaba, Oltacı!'), findsOneWidget);
    expect(find.text('Almanca biliyorum'), findsOneWidget);
  });
}
