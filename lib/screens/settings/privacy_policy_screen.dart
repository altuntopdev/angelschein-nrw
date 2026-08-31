import 'package:flutter/material.dart';

import '../../state/localization.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: Text(context.ui(tr: 'Gizlilik Politikası', de: 'Datenschutzerklärung'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Son güncelleme: 27 Ağustos 2026 · Stand: 27. August 2026',
                style: AppFonts.nunitoSans(fontSize: 12, color: onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 20),
            _Section(
              titleTr: 'Ne topluyoruz?',
              titleDe: 'Was wir erfassen',
              bodyTr:
                  'Uygulama, seni tanımlamak için bir isim, e-posta ya da telefon numarası istemez. İlk açılışta cihazına özel, anonim bir kimlik oluşturulur (Supabase Anonymous Auth). Bu kimlikle birlikte sadece şunlar kaydedilir: hangi soruları cevapladığın, doğru mu yanlış mı işaretlediğin, hangi sorudan devam edeceğin ve kaba bir platform bilgisi (Android/iOS/Web — kaç kullanıcının hangi platformdan geldiğini görebilmek için).',
                  bodyDe:
                  'Die App fragt weder nach Name, E-Mail noch Telefonnummer. Beim ersten Start wird eine anonyme, geräte­gebundene Kennung erstellt (Supabase Anonymous Auth). Darunter wird nur gespeichert, welche Fragen du beantwortet hast, ob richtig oder falsch, bei welcher Frage du weitermachen kannst, und eine grobe Plattforminformation (Android/iOS/Web — um zu sehen, wie viele Nutzer von welcher Plattform kommen).',
            ),
            _Section(
              titleTr: 'Ne için kullanıyoruz?',
              titleDe: 'Wofür wir es verwenden',
              bodyTr:
                  'Tek amaç: uygulamayı kapatıp tekrar açtığında kaldığın yerden devam edebilmen. Reklam, pazarlama, profil oluşturma ya da üçüncü taraflarla paylaşım için hiçbir veri kullanılmaz. Uygulamada reklam SDK\'sı, analitik/izleme SDK\'sı yoktur.',
              bodyDe:
                  'Einziger Zweck: Du kannst nach dem Schließen und erneuten Öffnen der App dort weitermachen, wo du aufgehört hast. Keine Daten werden für Werbung, Marketing, Profilbildung oder die Weitergabe an Dritte verwendet. Die App enthält keine Werbe- oder Tracking/Analyse-SDKs.',
            ),
            _Section(
              titleTr: 'Nerede saklanıyor?',
              titleDe: 'Wo es gespeichert wird',
              bodyTr:
                  'Veriler, veritabanı sağlayıcımız Supabase üzerinde saklanır ve bağlantı şifrelenmiş (HTTPS) olarak yapılır. Her kullanıcı sadece kendi anonim kimliğine ait veriyi görebilir — bu, veritabanı düzeyinde (Row Level Security) teknik olarak zorunlu kılınmıştır.',
              bodyDe:
                  'Die Daten werden bei unserem Datenbankanbieter Supabase gespeichert; die Verbindung ist verschlüsselt (HTTPS). Jeder Nutzer kann ausschließlich auf die Daten seiner eigenen anonymen Kennung zugreifen — dies wird auf Datenbankebene technisch erzwungen (Row Level Security).',
            ),
            _Section(
              titleTr: 'Verini nasıl silersin?',
              titleDe: 'Wie du deine Daten löschst',
              bodyTr:
                  'Ayarlar → "İlerlemeyi Sıfırla" ile senkronize edilmiş tüm ilerlemeni kalıcı olarak silebilirsin. Uygulamayı silmen, yalnızca cihazındaki yerel oturumu kaldırır; sunucudaki kaydı silmek istersen bu butonu kullanmalısın.',
              bodyDe:
                  'Unter Einstellungen → "Fortschritt zurücksetzen" kannst du deinen gesamten synchronisierten Fortschritt dauerhaft löschen. Das Deinstallieren der App entfernt nur die lokale Sitzung auf deinem Gerät; um den Serverdatensatz zu löschen, nutze diese Schaltfläche.',
            ),
            _Section(
              titleTr: 'Çocuklar',
              titleDe: 'Kinder',
              bodyTr: 'Uygulama genel kullanıcı kitlesine yöneliktir ve çocuklara özel bir veri toplama içermez.',
              bodyDe: 'Die App richtet sich an ein allgemeines Publikum und enthält keine kinderspezifische Datenerfassung.',
            ),
            _Section(
              titleTr: 'İletişim',
              titleDe: 'Kontakt',
              bodyTr: 'Sorularınız için: altuntop.dev@gmail.com',
              bodyDe: 'Bei Fragen: altuntop.dev@gmail.com',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titleTr;
  final String titleDe;
  final String bodyTr;
  final String bodyDe;

  const _Section({required this.titleTr, required this.titleDe, required this.bodyTr, required this.bodyDe});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$titleTr · $titleDe',
              style: AppFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.deepBlue)),
          const SizedBox(height: 6),
          Text(bodyTr, style: AppFonts.nunitoSans(fontSize: 13.5, height: 1.5, color: onSurface)),
          const SizedBox(height: 6),
          Text(bodyDe, style: AppFonts.nunitoSans(fontSize: 13, height: 1.5, color: onSurface.withValues(alpha: 0.65), fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
