# VoiceCam — sesli komutla video kaydı

Bağımsız bir Android uygulaması: bir kere “Dinlemeyi başlat” dedikten sonra
**ekran kapalıyken de** dinlemeye devam eder ve **“kayıt”** dediğinde video
kaydını başlatır, **“durdur”** dediğinde bitirir. Video `Movies/VoiceCam`
klasörüne MP4 olarak kaydedilir (galeride görünür).

Ekranda önizleme yoktur — amaç telefon cepteyken/kilitliyken çalışması. Dinleme
ve kayıt bir ön plan servisinde yapılır; durum bildirim çubuğunda görünür ve
oradan da başlatıp durdurabilirsin.

Bu klasör, depodaki Flutter uygulamasından tamamen ayrı bir Gradle projesidir;
Flutter tarafına hiçbir şey eklemez.

## Komutlar

| Ne dersen | Ne olur |
| --- | --- |
| **kayıt** · kaydı · kayıt başlat · kayda başla · videoyu başlat · başlat · kaydet | Kayıt başlar |
| kaydı durdur · kayıt durdur · kaydı bitir · durdur · dur · bitir | Kayıt biter, dosya kaydedilir |

İngilizce `start recording` / `stop recording` de çalışır. Eşleştirme Türkçe
karakterleri yok sayar (“Kaydı Başlat” = “kaydi baslat”) ve tam kelime arar,
yani “durum” kelimesi “dur” komutunu tetiklemez. Önce durdurma kelimelerine
bakılır, böylece “kayıt durdur” yanlışlıkla başlatma sayılmaz.

## Mikrofon ikilemi (önemli)

Android’de mikrofonu aynı anda tek taraf kullanabilir; konuşma tanıma da sesli
video kaydı da onu ister. Varsayılan: video **sessiz** kaydedilir, mikrofon
dinlemede kalır, yani “durdur” çalışır. “Videoyu sesli kaydet” anahtarını
açarsan ses kaydedilir ama kayıt boyunca dinleme durur — kaydı bildirimdeki
düğmeyle bitirirsin.

## Bip sesleri

Android’in konuşma tanıyıcısı her dinleme turunda bip çalar; sürekli dinlemede
bu rahatsız edici oluyordu. İki önlem var: Android 12+ cihazlarda önce
**cihaz üstü** tanıyıcı denenir (bu bip çalmaz, dili yoksa sistem tanıyıcısına
düşülür), ayrıca dinleme boyunca bip’in çıktığı ses kanalları (medya, sistem,
bildirim) sessize alınır — dinleme kapanınca geri açılır. Zil ve alarm kanalına
dokunulmaz, çağrıları kaçırmazsın.

## Kurulum

Android Studio ile `voice_cam_android` klasörünü aç ve çalıştır; ya da komut
satırından:

```bash
cd voice_cam_android
./gradlew installDebug      # telefon USB ile bağlı ve USB hata ayıklama açıkken
# veya sadece APK üretmek için:
./gradlew assembleDebug     # app/build/outputs/apk/debug/app-debug.apk
```

Gerekenler: JDK 17, Android SDK (compileSdk 36), minSdk 24 (Android 7.0+).

Bilgisayarına Android SDK kurmak istemiyorsan: depodaki
`.github/workflows/voicecam-apk.yml` iş akışını GitHub’da **Actions → VoiceCam
APK → Run workflow** ile çalıştır; testleri koşar, debug APK’yı üretir ve
çalışmanın **Artifacts** bölümüne `voicecam-debug-apk` olarak koyar. Zip’i indir,
içindeki `app-debug.apk`’yı telefona at ve “bilinmeyen kaynaklara izin ver”
diyerek kur.

İlk açılışta kamera ve mikrofon izni sorar. Konuşma tanıma için cihazda bir
tanıma servisi (çoğu telefonda Google uygulaması) kurulu olmalı. İnternetsiz
çalışması için **Ayarlar → Sistem → Diller ve giriş → Sesle yazma → Çevrimdışı
konuşma tanıma** bölümünden Türkçe dil paketini indir — paket kuruluysa tanıma
zaten cihaz üzerinde çalışır, yoksa internet gerekir.

## Nasıl çalışıyor

- `VoiceCamService.kt` — ön plan servisi (kamera + mikrofon tipi): CameraX
  `VideoCapture` (önizleme yok), MediaStore’a kayıt, bildirim, cihaz yönüne göre
  video rotasyonu. Servis uygulama ekrandayken başlatıldığı için ekran kapanınca
  da kamera/mikrofon erişimini korur.
- `MainActivity.kt` — sadece kontrol paneli: izinler, servisi başlat/durdur.
- `VoiceCommander.kt` — `SpeechRecognizer`’ı bir döngüde tutar (tanıyıcı her
  cümleden sonra kendini kapattığı için sonuç/hata sonrası yeniden başlatılır;
  hatalarda artan bekleme ile). Kısmi sonuçlara da bakar, böylece komut cümle
  bitmeden çalışır; aynı komut 2,5 saniye içinde tekrar tetiklenmez.
- `VoiceCommands.kt` — konuşma metnini komuta çeviren saf Kotlin kısmı
  (Android’e bağımlı değil), `app/src/test/.../VoiceCommandsTest.kt` ile test
  edilir: `./gradlew test`.

## Sınırlar

- Sürekli dinleme pili normalden hızlı tüketir; ayrıca bazı telefonlar arka
  plandaki uygulamayı öldürür — uygulamadaki “Pil optimizasyonunu kapat”
  düğmesinden VoiceCam’i listeden çıkar.
- Dinleme sırasında medya/sistem/bildirim sesleri sessize alınır (bip’leri
  bastırmak için); müzik dinlerken kullanmaya uygun değil.
- Servis ekran açıkken, uygulamanın içinden başlatılmalı — Android arka plandan
  kamera/mikrofon servisi başlatılmasına izin vermiyor.
- Arka kamera kullanılır; ön kameraya geçiş yok. Önizleme yok.

## Bu ortamda ne doğrulandı

Konteynerde Android SDK yok ve `dl.google.com` ağ politikası ile kapalı, bu
yüzden APK burada derlenemedi. Saf Kotlin komut eşleştirmesi (`VoiceCommands`)
ayrı bir JVM projesine kopyalanıp `VoiceCommandsTest`’teki 5 test çalıştırıldı;
hepsi geçti. Kamera/konuşma tarafı gerçek cihazda denenmelidir.
