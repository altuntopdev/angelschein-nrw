import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/content_repository.dart';
import 'screens/home/home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/missed_questions_controller.dart';
import 'services/progress_service.dart';
import 'services/supabase_config.dart';
import 'state/app_settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = AppSettings();
  final repository = ContentRepository();
  await Future.wait([settings.load(), repository.load()]);

  try {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  } catch (e) {
    debugPrint('Supabase.initialize failed (progress sync will be unavailable): $e');
  }
  final progress = ProgressService();
  // Best-effort — quiz progress sync degrades silently if this fails (offline,
  // anonymous sign-ins not enabled yet, etc.), the quiz itself still works.
  unawaited(progress.ensureSignedIn());

  runApp(AngelscheinApp(settings: settings, repository: repository, progress: progress));
}

class AngelscheinApp extends StatelessWidget {
  final AppSettings settings;
  final ContentRepository repository;
  final ProgressService progress;

  const AngelscheinApp({super.key, required this.settings, required this.repository, required this.progress});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider.value(value: repository),
        Provider.value(value: progress),
        ChangeNotifierProvider(create: (_) => MissedQuestionsController(progress)..refresh()),
      ],
      child: Consumer<AppSettings>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Angelschein NRW',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: settings.onboardingDone ? const HomeShell() : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
