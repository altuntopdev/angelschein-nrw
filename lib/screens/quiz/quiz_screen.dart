import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/question.dart';
import '../../services/progress_service.dart';
import '../../state/app_settings.dart';
import '../../state/localization.dart';
import '../../theme/app_theme.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String title;
  final List<ExamQuestion> questions;

  /// The official written Fischerprüfung allows 60 minutes (§ 5 Abs. 3
  /// Fischerprüfungsordnung NRW). Pass this for the mock exam; leave null
  /// for untimed category study.
  final Duration? timeLimit;

  /// 'category' | 'mock_exam' — identifies this run for Supabase progress
  /// sync (resume / restart).
  final String mode;
  final String? categorySlug;

  /// Set when resuming a previously saved, in-progress session.
  final String? resumeSessionId;
  final int initialIndex;
  final List<bool> initialResults;
  final int? initialRemainingSeconds;

  const QuizScreen({
    super.key,
    required this.title,
    required this.questions,
    this.timeLimit,
    required this.mode,
    this.categorySlug,
    this.resumeSessionId,
    this.initialIndex = 0,
    this.initialResults = const [],
    this.initialRemainingSeconds,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late int _index = widget.initialIndex;
  String? _selectedLetter;
  late final List<bool> _results = List<bool>.from(widget.initialResults);
  Timer? _timer;
  Duration? _remaining;
  String? _sessionId;

  ExamQuestion get _current => widget.questions[_index];
  bool get _answered => _selectedLetter != null;
  bool get _lastAnswerCorrect => _selectedLetter == _current.de.correctOption.letter;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.resumeSessionId;

    final startSeconds = widget.resumeSessionId != null ? widget.initialRemainingSeconds : widget.timeLimit?.inSeconds;
    if (startSeconds != null) {
      _remaining = Duration(seconds: startSeconds);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }

    if (_sessionId == null) {
      unawaited(_createSession());
    }
  }

  Future<void> _createSession() async {
    final id = await context.read<ProgressService>().createSession(
          mode: widget.mode,
          category: widget.categorySlug,
          questionIds: widget.questions.map((q) => q.id).toList(),
          timeLimitSeconds: widget.timeLimit?.inSeconds,
        );
    if (mounted) {
      setState(() => _sessionId = id);
    } else {
      _sessionId = id;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _remaining! - const Duration(seconds: 1);
    if (remaining <= Duration.zero) {
      _timer?.cancel();
      _finish(timedOut: true);
      return;
    }
    setState(() => _remaining = remaining);
  }

  void _select(String letter) {
    if (_answered) return;
    final correct = letter == _current.de.correctOption.letter;
    setState(() {
      _selectedLetter = letter;
      _results.add(correct);
    });
    context.read<ProgressService>().logAttempt(
          sessionId: _sessionId,
          questionId: _current.id,
          category: _current.category.slug,
          isCorrect: correct,
        );
  }

  void _next() {
    if (_index == widget.questions.length - 1) {
      _finish();
      return;
    }
    final newIndex = _index + 1;
    if (_sessionId != null) {
      context.read<ProgressService>().checkpoint(
            sessionId: _sessionId!,
            currentIndex: newIndex,
            results: List<bool>.from(_results),
            remainingSeconds: _remaining?.inSeconds,
          );
    }
    setState(() {
      _index = newIndex;
      _selectedLetter = null;
    });
  }

  void _finish({bool timedOut = false}) {
    _timer?.cancel();
    // Unanswered questions (only possible on timeout) count as wrong, same as
    // leaving them blank in the real exam.
    final results = List<bool>.from(_results);
    if (timedOut) {
      results.addAll(List.filled(widget.questions.length - results.length, false));
    }
    if (_sessionId != null) {
      context.read<ProgressService>().completeSession(_sessionId);
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => QuizResultScreen(questions: widget.questions, results: results),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dualLanguage = context.watch<AppSettings>().dualLanguageMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final mintTint = isDark ? AppColors.mintTintDark : AppColors.mintTint;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final q = _current;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_index + 1) / widget.questions.length,
                        minHeight: 12,
                        backgroundColor: mintTint,
                        valueColor: const AlwaysStoppedAnimation(AppColors.seafoam),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3DD), borderRadius: BorderRadius.circular(10)),
                    child: Text('${_index + 1}/${widget.questions.length}',
                        style: AppFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFFB5651D))),
                  ),
                  if (_remaining != null) ...[
                    const SizedBox(width: 8),
                    _TimerChip(remaining: _remaining!),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 24, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.de.question, style: AppFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 19, height: 1.35, color: onSurface)),
                          const SizedBox(height: 18),
                          ...q.de.options.map((opt) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OptionPill(
                                  letter: opt.letter,
                                  text: opt.text,
                                  isCorrect: opt.correct,
                                  isSelected: _selectedLetter == opt.letter,
                                  revealed: _answered,
                                  onTap: () => _select(opt.letter),
                                ),
                              )),
                        ],
                      ),
                    ),
                    if (_answered && dualLanguage) ...[
                      const SizedBox(height: 14),
                      _TurkishReveal(question: q, correct: _lastAnswerCorrect),
                    ],
                    if (_answered && !dualLanguage) ...[
                      const SizedBox(height: 14),
                      _GermanReveal(question: q, correct: _lastAnswerCorrect),
                    ],
                  ],
                ),
              ),
            ),
            if (_answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: _ChunkyButton(
                  label: _index == widget.questions.length - 1
                      ? context.ui(tr: 'SONUÇLARI GÖR', de: 'ERGEBNISSE ANZEIGEN')
                      : context.ui(tr: 'İLERİ', de: 'WEITER'),
                  onTap: _next,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  final Duration remaining;
  const _TimerChip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final low = remaining <= const Duration(minutes: 5);
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final bg = low ? AppColors.dangerBg : const Color(0xFFEAF6F5);
    final fg = low ? AnswerColors.incorrectFallback : AppColors.deepBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: fg),
          const SizedBox(width: 3),
          Text('$minutes:$seconds', style: AppFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 12, color: fg)),
        ],
      ),
    );
  }
}

class _ChunkyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChunkyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deepBlue,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Color(0xFF082C3F), offset: Offset(0, 5))],
          ),
          child: Text(label, style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.4)),
        ),
      ),
    );
  }
}

class _OptionPill extends StatelessWidget {
  final String letter;
  final String text;
  final bool isCorrect;
  final bool isSelected;
  final bool revealed;
  final VoidCallback onTap;

  const _OptionPill({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isSelected,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neutralBg = isDark ? AppColors.mintTintDark : const Color(0xFFF2FBFA);
    final neutralBorder = isDark ? Colors.white24 : const Color(0xFFDDEFED);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Color bg = neutralBg;
    Color border = neutralBorder;
    Color fg = onSurface;
    Color badgeBg = neutralBorder;
    Color badgeFg = onSurface;
    Widget badgeChild = Text(letter.toUpperCase(), style: AppFonts.baloo2(fontSize: 12, fontWeight: FontWeight.w700, color: badgeFg));
    double opacity = 1;

    if (revealed) {
      if (isCorrect) {
        bg = AppColors.successBg;
        border = AppColors.moss;
        fg = AppColors.successFg;
        badgeBg = AppColors.moss;
        badgeChild = const Icon(Icons.check, color: Colors.white, size: 15);
      } else if (isSelected) {
        bg = AppColors.dangerBg;
        border = AnswerColors.incorrectFallback;
        fg = AnswerColors.incorrectFallback;
        badgeBg = AnswerColors.incorrectFallback;
        badgeChild = const Icon(Icons.close, color: Colors.white, size: 15);
      } else {
        opacity = 0.55;
      }
    }

    return Opacity(
      opacity: opacity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: revealed ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 2)),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: badgeChild,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: AppFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 14.5, color: fg))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TurkishReveal extends StatelessWidget {
  final ExamQuestion question;
  final bool correct;

  const _TurkishReveal({required this.question, required this.correct});

  @override
  Widget build(BuildContext context) {
    final bg = correct ? AppColors.successBg : AppColors.dangerBg;
    final fg = correct ? AppColors.successFg : AnswerColors.incorrectFallback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(correct ? Icons.check : Icons.close, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 8),
              Text(correct ? 'Harika, doğru!' : 'Olsun, bir dahaki sefere!',
                  style: AppFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 15, color: fg)),
            ],
          ),
          const SizedBox(height: 10),
          Text(question.tr.question, style: AppFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.deepBlue)),
          const SizedBox(height: 6),
          ...question.tr.options.map((opt) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${opt.letter}) ${opt.text}${opt.correct ? '  ✓' : ''}',
                  style: AppFonts.nunitoSans(
                    fontWeight: opt.correct ? FontWeight.w800 : FontWeight.w400,
                    fontSize: 13,
                    color: opt.correct ? AppColors.successFg : const Color(0xFF3D5A63),
                  ),
                ),
              )),
          if (question.tr.note != null) ...[
            const SizedBox(height: 8),
            Text(question.tr.note!, style: AppFonts.nunitoSans(fontSize: 12, color: const Color(0xFF4B7A6A), height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// The "Almanca biliyorum" (fully-German) reveal. Since the source material
/// only has explanatory notes in Turkish (never a native German sentence),
/// this deliberately does not machine-translate them — that would risk
/// putting unverified text into exam-prep content. Instead it reinforces the
/// correct answer in German, which is data we already trust.
class _GermanReveal extends StatelessWidget {
  final ExamQuestion question;
  final bool correct;

  const _GermanReveal({required this.question, required this.correct});

  @override
  Widget build(BuildContext context) {
    final bg = correct ? AppColors.successBg : AppColors.dangerBg;
    final fg = correct ? AppColors.successFg : AnswerColors.incorrectFallback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(correct ? Icons.check : Icons.close, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 8),
              Text(correct ? 'Richtig!' : 'Leider nicht',
                  style: AppFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 15, color: fg)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Richtige Antwort', style: AppFonts.nunitoSans(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.deepBlue)),
          const SizedBox(height: 2),
          Text(question.de.correctOption.text,
              style: AppFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.successFg)),
        ],
      ),
    );
  }
}
