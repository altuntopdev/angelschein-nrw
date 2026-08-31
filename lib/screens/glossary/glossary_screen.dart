import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../models/glossary_term.dart';
import '../../state/localization.dart';
import '../../theme/app_theme.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ContentRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final fluent = context.isFluentGerman;
    final q = _query.trim().toLowerCase();
    final terms = q.isEmpty
        ? repo.glossary
        : repo.glossary.where((t) => t.de.toLowerCase().contains(q) || t.tr.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              decoration: const BoxDecoration(gradient: AppColors.gradientHeader),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.ui(tr: 'Sözlük', de: 'Wörterbuch'),
                      style: AppFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
                  const SizedBox(height: 2),
                  Text(
                      fluent
                          ? '${repo.glossary.length} Begriffe · Deutsche Definitionen'
                          : '${repo.glossary.length} terim · Almanca · Türkçe · Latince',
                      style: AppFonts.nunitoSans(color: const Color(0xFFCFEFEA), fontSize: 12.5)),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      style: AppFonts.nunitoSans(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.ui(tr: 'Terim ara...', de: 'Begriff suchen...'),
                        hintStyle: AppFonts.nunitoSans(fontSize: 13.5, color: const Color(0xFF8592A0)),
                        prefixIcon: const Icon(Icons.search, color: AppColors.deepBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: terms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _GlossaryRow(term: terms[i], cardColor: cardColor, onSurface: onSurface, fluent: fluent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlossaryRow extends StatelessWidget {
  final GlossaryTerm term;
  final Color cardColor;
  final Color onSurface;
  final bool fluent;
  const _GlossaryRow({required this.term, required this.cardColor, required this.onSurface, required this.fluent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(term.de, style: AppFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 15.5, color: onSurface)),
          const SizedBox(height: 2),
          Text(fluent ? (term.deDefinition ?? term.tr) : term.tr,
              style: AppFonts.nunitoSans(color: onSurface.withValues(alpha: 0.72), fontSize: 13)),
          if (term.latin != null) ...[
            const SizedBox(height: 3),
            Text(term.latin!, style: AppFonts.nunitoSans(color: AppColors.teal, fontStyle: FontStyle.italic, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}
