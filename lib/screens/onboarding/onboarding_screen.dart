import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icons.dart';
import '../home/home_shell.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              Transform.translate(
                offset: const Offset(0, -26),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  child: _LevelCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 46),
      decoration: const BoxDecoration(
        gradient: AppColors.gradientHeader,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text('A', style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Text('ANGELSCHEIN NRW',
                  style: AppFonts.nunitoSans(color: const Color(0xFFDFF6F2), fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 4),
          const FishMascot(width: 118, height: 90),
          const SizedBox(height: 4),
          Text('Merhaba, Oltacı!',
              style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 26)),
          const SizedBox(height: 2),
          Text('NRW balıkçılık sınavına birlikte hazırlanalım',
              textAlign: TextAlign.center,
              style: AppFonts.nunitoSans(color: const Color(0xFFCFEFEA), fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.deepBlue.withValues(alpha: 0.16), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Almancan nasıl?', style: AppFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.deepBlue)),
          Text('Wie ist dein Deutsch?', style: AppFonts.nunitoSans(fontSize: 12.5, color: const Color(0xFF5B7D86))),
          const SizedBox(height: 16),
          _OptionPill(
            background: AppColors.deepBlue,
            foreground: Colors.white,
            badge: Text('DE', style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            badgeBg: Colors.white.withValues(alpha: 0.16),
            title: 'Almanca biliyorum',
            subtitle: 'Uygulama tamamen Almanca',
            subtitleOpacity: 0.75,
            onTap: () => _select(context, GermanLevel.fluent),
          ),
          const SizedBox(height: 10),
          _OptionPill(
            background: AppColors.teal,
            foreground: Colors.white,
            badge: CustomPaint(size: const Size(18, 18), painter: _MiniFishPainter(color: Colors.white)),
            badgeBg: Colors.white.withValues(alpha: 0.18),
            title: 'Biraz biliyorum',
            subtitle: 'Cevap sonrası Türkçe gösterilir',
            subtitleOpacity: 0.85,
            onTap: () => _select(context, GermanLevel.little),
          ),
          const SizedBox(height: 10),
          _OptionPill(
            background: const Color(0xFFF2FBFA),
            foreground: AppColors.deepBlue,
            border: const Color(0xFFCFEFEA),
            badge: CustomPaint(size: const Size(18, 18), painter: _MiniRodPainter(color: AppColors.deepBlue)),
            badgeBg: const Color(0xFFDFF6F2),
            title: 'Bilmiyorum',
            subtitle: 'Cevap sonrası Türkçe gösterilir',
            subtitleOpacity: 0.7,
            onTap: () => _select(context, GermanLevel.none),
          ),
        ],
      ),
    );
  }

  void _select(BuildContext context, GermanLevel level) async {
    await context.read<AppSettings>().completeOnboarding(level);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }
}

class _OptionPill extends StatelessWidget {
  final Color background;
  final Color foreground;
  final Color? border;
  final Widget badge;
  final Color badgeBg;
  final String title;
  final String subtitle;
  final double subtitleOpacity;
  final VoidCallback onTap;

  const _OptionPill({
    required this.background,
    required this.foreground,
    this.border,
    required this.badge,
    required this.badgeBg,
    required this.title,
    required this.subtitle,
    required this.subtitleOpacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: border != null ? Border.all(color: border!, width: 2) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: badge,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppFonts.nunitoSans(fontWeight: FontWeight.w800, fontSize: 14.5, color: foreground)),
                    Text(subtitle, style: AppFonts.nunitoSans(fontSize: 11.5, color: foreground.withValues(alpha: subtitleOpacity))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniFishPainter extends CustomPainter {
  final Color color;
  _MiniFishPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(2, 12)
      ..cubicTo(5, 8, 10, 6, 15, 6)
      ..cubicTo(18, 6, 20, 8, 22, 12)
      ..cubicTo(20, 16, 18, 18, 15, 18)
      ..cubicTo(10, 18, 5, 16, 2, 12)
      ..close();
    canvas.drawPath(body, stroke);
    canvas.drawCircle(const Offset(7, 11), 0.9, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniFishPainter oldDelegate) => oldDelegate.color != color;
}

class _MiniRodPainter extends CustomPainter {
  final Color color;
  _MiniRodPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(4, 20), const Offset(18, 5), stroke);
    canvas.drawLine(const Offset(18, 5), const Offset(19.6, 3.4), stroke);
    canvas.drawCircle(const Offset(15, 9), 2, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniRodPainter oldDelegate) => oldDelegate.color != color;
}
