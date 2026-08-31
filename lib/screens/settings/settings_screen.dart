import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/progress_service.dart';
import '../../state/app_settings.dart';
import '../../state/localization.dart';
import '../../theme/app_theme.dart';
import 'privacy_policy_screen.dart';

const _kSupportEmail = 'altuntop.dev@gmail.com';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(context.ui(tr: 'Ayarlar', de: 'Einstellungen'),
                style: AppFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 26, color: onSurface)),
            const SizedBox(height: 20),
            _SectionCard(
              cardColor: cardColor,
              title: context.ui(tr: 'Almanca seviyesi', de: 'Deutschniveau'),
              subtitle: context.ui(
                tr: 'Sorular ve cevaplar hangi dilde gösterilecek, buna göre belirlenir.',
                de: 'Bestimmt, in welcher Sprache Fragen und Antworten angezeigt werden.',
              ),
              child: Column(
                children: [
                  _RadioRow<GermanLevel>(
                    label: context.ui(tr: 'Almanca biliyorum', de: 'Ich kann Deutsch'),
                    subtitle: context.ui(tr: 'Uygulama tamamen Almanca çalışır', de: 'Die App läuft komplett auf Deutsch'),
                    value: GermanLevel.fluent,
                    groupValue: settings.germanLevel,
                    onChanged: (v) => _confirmLevelChange(context, settings, v),
                  ),
                  _RadioRow<GermanLevel>(
                    label: context.ui(tr: 'Biraz biliyorum', de: 'Ich kann ein bisschen Deutsch'),
                    subtitle: context.ui(
                      tr: 'Cevapladıktan sonra çeviri ve açıklama gösterilir',
                      de: 'Nach der Antwort werden Übersetzung und Erklärung angezeigt',
                    ),
                    value: GermanLevel.little,
                    groupValue: settings.germanLevel,
                    onChanged: (v) => _confirmLevelChange(context, settings, v),
                  ),
                  _RadioRow<GermanLevel>(
                    label: context.ui(tr: 'Bilmiyorum', de: 'Ich kann kein Deutsch'),
                    subtitle: context.ui(
                      tr: 'Cevapladıktan sonra çeviri ve açıklama gösterilir',
                      de: 'Nach der Antwort werden Übersetzung und Erklärung angezeigt',
                    ),
                    value: GermanLevel.none,
                    groupValue: settings.germanLevel,
                    onChanged: (v) => _confirmLevelChange(context, settings, v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              cardColor: cardColor,
              title: context.ui(tr: 'Görünüm', de: 'Ansicht'),
              child: Column(
                children: [
                  _RadioRow<ThemeMode>(
                    label: context.ui(tr: 'Açık', de: 'Hell'),
                    value: ThemeMode.light,
                    groupValue: settings.themeMode,
                    onChanged: settings.setThemeMode,
                  ),
                  _RadioRow<ThemeMode>(
                    label: context.ui(tr: 'Koyu', de: 'Dunkel'),
                    value: ThemeMode.dark,
                    groupValue: settings.themeMode,
                    onChanged: settings.setThemeMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              cardColor: cardColor,
              title: context.ui(tr: 'Hakkında', de: 'Über'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LinkRow(
                    label: context.ui(tr: 'Gizlilik Politikası', de: 'Datenschutzerklärung'),
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                  ),
                  _LinkRow(
                    label: context.ui(tr: 'Destek / İletişim', de: 'Support / Kontakt'),
                    icon: Icons.mail_outline,
                    onTap: () => launchUrl(Uri(scheme: 'mailto', path: _kSupportEmail)),
                  ),
                  _LinkRow(
                    label: context.ui(tr: 'İlerlemeyi Sıfırla', de: 'Fortschritt zurücksetzen'),
                    icon: Icons.delete_outline,
                    danger: true,
                    onTap: () => _confirmResetProgress(context),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      final version = info == null ? '' : 'v${info.version} (${info.buildNumber})';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(version,
                            style: AppFonts.nunitoSans(fontSize: 11.5, color: onSurface.withValues(alpha: 0.45))),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResetProgress(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.uiRead(tr: 'İlerlemeyi sıfırla', de: 'Fortschritt zurücksetzen')),
        content: Text(context.uiRead(
          tr: 'Senkronize edilmiş tüm sınav geçmişin ve kaldığın yerler kalıcı olarak silinecek. Bu işlem geri alınamaz. Devam edilsin mi?',
          de: 'Dein gesamter synchronisierter Prüfungsverlauf und Fortschritt wird dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden. Fortfahren?',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.uiRead(tr: 'Vazgeç', de: 'Abbrechen'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AnswerColors.incorrectFallback),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.uiRead(tr: 'Sil', de: 'Löschen')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await context.read<ProgressService>().resetAllProgress();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? context.uiRead(tr: 'İlerlemen silindi.', de: 'Dein Fortschritt wurde gelöscht.')
          : context.uiRead(tr: 'Silinemedi, internet bağlantını kontrol et.', de: 'Löschen fehlgeschlagen, prüfe deine Internetverbindung.')),
    ));
  }

  Future<void> _confirmLevelChange(BuildContext context, AppSettings settings, GermanLevel newLevel) async {
    if (settings.germanLevel == newLevel) return;

    final willBeFluent = newLevel == GermanLevel.fluent;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.uiRead(tr: 'Almanca seviyeni değiştir', de: 'Deutschniveau ändern')),
        content: Text(
          willBeFluent
              ? context.uiRead(
                  tr: 'Uygulama artık tamamen Almanca çalışacak: sorular, cevaplar ve açıklamalar Türkçe gösterilmeyecek. Devam edilsin mi?',
                  de: 'Die App läuft jetzt komplett auf Deutsch: Fragen, Antworten und Erklärungen werden nicht mehr auf Türkisch angezeigt. Fortfahren?',
                )
              : context.uiRead(
                  tr: 'Sorular cevapladıktan sonra çeviri ve açıklama gösterilecek. Devam edilsin mi?',
                  de: 'Nach der Antwort werden Übersetzung und Erklärung angezeigt. Fortfahren?',
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(context.uiRead(tr: 'Vazgeç', de: 'Abbrechen'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(context.uiRead(tr: 'Onayla', de: 'Bestätigen'))),
        ],
      ),
    );

    if (confirmed == true) {
      await settings.setGermanLevel(newLevel);
    }
  }
}

class _SectionCard extends StatelessWidget {
  final Color cardColor;
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.cardColor, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 15, color: onSurface)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppFonts.nunitoSans(fontSize: 12, color: onSurface.withValues(alpha: 0.65))),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _LinkRow({required this.label, required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = danger ? AnswerColors.incorrectFallback : onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 14, color: color))),
            Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _RadioRow<T> extends StatelessWidget {
  final String label;
  final String? subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  const _RadioRow({required this.label, this.subtitle, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.seafoam : onSurface.withValues(alpha: 0.3), width: 2),
                color: selected ? AppColors.seafoam : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: selected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppFonts.nunitoSans(fontWeight: FontWeight.w600, fontSize: 14, color: onSurface)),
                  if (subtitle != null)
                    Text(subtitle!, style: AppFonts.nunitoSans(fontSize: 11.5, color: onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
