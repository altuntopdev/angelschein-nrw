import 'package:flutter/material.dart';

import '../../models/question.dart';
import '../../state/localization.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';

class QuizResultScreen extends StatelessWidget {
  final List<ExamQuestion> questions;
  final List<bool> results;

  const QuizResultScreen({super.key, required this.questions, required this.results});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fluent = context.isFluentGerman;
    final correctCount = results.where((r) => r).length;
    final total = results.length;
    final ratio = total == 0 ? 0.0 : correctCount / total;

    final byCategory = <ExamCategory, List<bool>>{};
    for (var i = 0; i < questions.length; i++) {
      byCategory.putIfAbsent(questions[i].category, () => []).add(results[i]);
    }

    // Official NRW exam pass rule (Fischerprüfungsordnung § 6 Abs. 2): at least
    // 45 of 60 questions correct overall, AND at least 6 of 10 correct in every
    // individual subject area.
    const minOverallCorrect = 45;
    const minPerCategoryCorrect = 6;
    final passesOverall = correctCount >= minOverallCorrect;
    final passesByCategory = byCategory.values.every((r) => r.where((x) => x).length >= minPerCategoryCorrect);
    final passed = total >= 60 ? (passesOverall && passesByCategory) : null;

    return Scaffold(
      appBar: AppBar(title: Text(context.ui(tr: 'Sonuç', de: 'Ergebnis'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: const BoxDecoration(gradient: AppColors.gradientHeader, borderRadius: BorderRadius.all(Radius.circular(24))),
              child: Column(
                children: [
                  Text('$correctCount / $total',
                      style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40)),
                  const SizedBox(height: 2),
                  Text(context.ui(tr: '%${(ratio * 100).toStringAsFixed(0)} doğru', de: '${(ratio * 100).toStringAsFixed(0)}% richtig'),
                      style: AppFonts.nunitoSans(color: const Color(0xFFCFEFEA), fontSize: 13)),
                  if (passed != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                      child: Text(context.ui(tr: passed ? 'Geçtin!' : 'Bu sefer olmadı', de: passed ? 'Bestanden!' : 'Diesmal nicht geschafft'),
                          style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                  if (passed != null) ...[
                    const SizedBox(height: 8),
                    Text(
                        context.ui(
                          tr: 'Resmi kural: en az 45/60 ve her kategoriden en az 6/10',
                          de: 'Offizielle Regel: mind. 45/60 und je Bereich mind. 6/10',
                        ),
                        style: AppFonts.nunitoSans(color: const Color(0xFFCFEFEA), fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(context.ui(tr: 'Kategori bazında', de: 'Nach Bereich'),
                style: AppFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 16, color: onSurface)),
            const SizedBox(height: 12),
            ...byCategory.entries.map((e) {
              final correct = e.value.where((x) => x).length;
              final belowMinimum = e.value.length >= 10 && correct < minPerCategoryCorrect;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: e.key.accentColor, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(fluent ? e.key.nameDe : e.key.nameTr,
                            style: AppFonts.nunitoSans(fontWeight: FontWeight.w600, color: onSurface))),
                    Text('$correct/${e.value.length}',
                        style: AppFonts.baloo2(
                          fontWeight: FontWeight.w700,
                          color: belowMinimum ? AnswerColors.incorrectFallback : onSurface,
                        )),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(context.ui(tr: 'Ana sayfaya dön', de: 'Zur Startseite')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
