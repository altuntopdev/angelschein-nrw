import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../models/question.dart';
import '../../services/missed_questions_controller.dart';
import '../../services/progress_service.dart';
import '../../state/localization.dart';
import 'quiz_result_screen.dart';
import 'quiz_screen.dart';

enum _ResumeAction { resume, restart }

/// Starts a quiz (category study, mock exam, or mistakes review), first
/// checking Supabase for an in-progress session of the same kind and — if
/// found — asking the user whether to resume it or start over. Falls back to
/// starting fresh with no prompt if there's no saved session, or if progress
/// sync is unavailable. Always refreshes [MissedQuestionsController] once the
/// user is back out of the quiz, regardless of which screen launched it —
/// that's the one place every quiz-taking path passes through.
Future<void> launchQuiz(
  BuildContext context, {
  required String mode,
  String? categorySlug,
  required String title,
  required List<ExamQuestion> Function() buildFreshQuestions,
  Duration? timeLimit,
}) async {
  await _launchQuiz(
    context,
    mode: mode,
    categorySlug: categorySlug,
    title: title,
    buildFreshQuestions: buildFreshQuestions,
    timeLimit: timeLimit,
  );
  if (context.mounted) {
    await context.read<MissedQuestionsController>().refresh();
  }
}

Future<void> _launchQuiz(
  BuildContext context, {
  required String mode,
  String? categorySlug,
  required String title,
  required List<ExamQuestion> Function() buildFreshQuestions,
  Duration? timeLimit,
}) async {
  final progress = context.read<ProgressService>();
  final repo = context.read<ContentRepository>();

  final saved = await progress.findResumable(mode: mode, category: categorySlug);

  if (saved != null) {
    final resumedQuestions = repo.byIds(saved.questionIds);
    final intact = resumedQuestions.length == saved.questionIds.length && resumedQuestions.isNotEmpty;

    if (!intact) {
      // Content changed underneath this saved session (shouldn't normally
      // happen) — it can't be resumed, so drop it quietly and start fresh.
      await progress.discardSession(saved.id);
    } else if (saved.results.length >= resumedQuestions.length) {
      // Every question was already answered but the app closed before the
      // session could be marked complete — just show the result.
      await progress.completeSession(saved.id);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizResultScreen(questions: resumedQuestions, results: saved.results),
      ));
      return;
    } else {
      if (!context.mounted) return;
      final action = await showDialog<_ResumeAction>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.uiRead(tr: 'Devam eden bir sınavın var', de: 'Du hast eine laufende Prüfung')),
          content: Text(context.uiRead(
            tr: 'Kaldığın yerden devam edebilir ya da baştan başlayabilirsin.',
            de: 'Du kannst dort weitermachen oder von vorne beginnen.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_ResumeAction.restart),
              child: Text(context.uiRead(tr: 'Baştan Başla', de: 'Neu starten')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(_ResumeAction.resume),
              child: Text(context.uiRead(tr: 'Devam Et', de: 'Weiter')),
            ),
          ],
        ),
      );

      if (action == _ResumeAction.resume) {
        if (!context.mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuizScreen(
            title: title,
            questions: resumedQuestions,
            timeLimit: saved.timeLimitSeconds != null ? Duration(seconds: saved.timeLimitSeconds!) : null,
            mode: mode,
            categorySlug: categorySlug,
            resumeSessionId: saved.id,
            initialIndex: saved.currentIndex,
            initialResults: saved.results,
            initialRemainingSeconds: saved.remainingSeconds,
          ),
        ));
        return;
      } else if (action == _ResumeAction.restart) {
        await progress.discardSession(saved.id);
      } else {
        // Dialog dismissed without a choice — leave the saved session alone.
        return;
      }
    }
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => QuizScreen(
      title: title,
      questions: buildFreshQuestions(),
      timeLimit: timeLimit,
      mode: mode,
      categorySlug: categorySlug,
    ),
  ));
}
