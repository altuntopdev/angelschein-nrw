import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../state/localization.dart';
import '../../theme/app_theme.dart';
import '../quiz/quiz_launcher.dart';

class MockExamIntroScreen extends StatelessWidget {
  const MockExamIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final repo = context.read<ContentRepository>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(gradient: AppColors.gradientHeader, borderRadius: BorderRadius.all(Radius.circular(24))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.timer_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 14),
                    Text(context.ui(tr: '60 Soruluk\nDeneme Sınavı', de: '60 Fragen\nProbeprüfung'),
                        style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24, height: 1.15)),
                    const SizedBox(height: 8),
                    Text(
                        context.ui(
                          tr: 'Gerçek NRW sınavını simüle eder: 6 kategoriden 10\'ar soru, 60 dakika süre.',
                          de: 'Simuliert die echte NRW-Prüfung: 10 Fragen aus 6 Bereichen, 60 Minuten Zeit.',
                        ),
                        style: AppFonts.nunitoSans(color: const Color(0xFFCFEFEA), fontSize: 13.5, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.ui(
                          tr: 'Sorular gerçek sınavdaki gibi önce sadece Almanca gösterilir; cevapladıktan sonra çeviri açılır. Resmi geçme kuralı (Fischerprüfungsordnung § 6): en az 45/60 doğru, her kategoriden en az 6/10 doğru.',
                          de: 'Fragen erscheinen wie in der echten Prüfung zuerst nur auf Deutsch. Offizielle Bestehensregel (Fischerprüfungsordnung § 6): mindestens 45/60 richtig, davon mindestens 6/10 je Bereich.',
                        ),
                        style: AppFonts.nunitoSans(fontSize: 12.5, color: onSurface.withValues(alpha: 0.75), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Material(
                color: AppColors.deepBlue,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    final examTitle = context.uiRead(tr: 'Deneme Sınavı', de: 'Probeprüfung');
                    launchQuiz(
                      context,
                      mode: 'mock_exam',
                      title: examTitle,
                      buildFreshQuestions: () => repo.buildMockExam(),
                      timeLimit: const Duration(minutes: 60),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Color(0xFF082C3F), offset: Offset(0, 5))],
                    ),
                    child: Text(context.ui(tr: 'SINAVI BAŞLAT', de: 'PRÜFUNG STARTEN'),
                        style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.4)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
