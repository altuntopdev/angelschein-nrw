import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../models/question.dart';
import '../../services/missed_questions_controller.dart';
import '../../state/localization.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../quiz/quiz_launcher.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  void _reviewMistakes(BuildContext context, List<String> missedIds) {
    final repo = context.read<ContentRepository>();
    final title = context.uiRead(tr: 'Yanlış Yaptıklarım', de: 'Meine Fehler');
    launchQuiz(
      context,
      mode: 'mistakes_review',
      title: title,
      buildFreshQuestions: () => repo.byIds(missedIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ContentRepository>();
    final total = repo.totalQuestionCount;
    final missedIds = context.watch<MissedQuestionsController>().missedIds;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: const BoxDecoration(gradient: AppColors.gradientHeader),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.ui(tr: 'Kategoriler', de: 'Kategorien'),
                        style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
                    const SizedBox(height: 2),
                    Text(context.ui(tr: '6 bölüm · $total soru', de: '6 Bereiche · $total Fragen'),
                        style: AppFonts.nunitoSans(color: const Color(0xFFCFEFEA), fontSize: 12.5)),
                  ],
                ),
              ),
              if (missedIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _MistakesBanner(count: missedIds.length, onTap: () => _reviewMistakes(context, missedIds)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.12,
                  children: ExamCategory.values.map((category) {
                    final count = repo.questionsFor(category).length;
                    return _CategoryTile(category: category, count: count);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MistakesBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _MistakesBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3DD),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Icon(Icons.flag_rounded, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.ui(tr: 'Yanlış Yaptıklarım', de: 'Meine Fehler'),
                      style: AppFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 14.5, color: const Color(0xFF8A4B10)),
                    ),
                    Text(
                      context.ui(tr: '$count soruyu tekrar çalış', de: '$count Fragen wiederholen'),
                      style: AppFonts.nunitoSans(fontSize: 12, color: const Color(0xFFB5651D)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB5651D), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ExamCategory category;
  final int count;

  const _CategoryTile({required this.category, required this.count});

  @override
  Widget build(BuildContext context) {
    final accent = category.accentColor;
    final onAccent = Colors.white;
    final fluent = context.isFluentGerman;

    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: count == 0
            ? null
            : () => launchQuiz(
                  context,
                  mode: 'category',
                  categorySlug: category.slug,
                  title: fluent ? category.nameDe : category.nameTr,
                  buildFreshQuestions: () => context.read<ContentRepository>().studySetFor(category),
                ),
        child: Stack(
          children: [
            // oversized watermark icon fills the empty background space
            Positioned(
              right: -14,
              bottom: -14,
              child: Opacity(
                opacity: 0.16,
                child: CategoryIcon(category: category, color: Colors.white, size: 64),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: onAccent.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: CategoryIcon(category: category, color: onAccent, size: 16),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fluent ? category.nameDe : category.nameTr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.nunitoSans(color: onAccent, fontWeight: FontWeight.w800, fontSize: 12, height: 1.15),
                  ),
                  if (!fluent) ...[
                    const SizedBox(height: 1),
                    Text(
                      category.nameDe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.nunitoSans(color: onAccent.withValues(alpha: 0.72), fontWeight: FontWeight.w600, fontSize: 9.5),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(7)),
                    child: Text(fluent ? '$count Fragen' : '$count soru',
                        style: AppFonts.nunitoSans(color: onAccent, fontWeight: FontWeight.w700, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
