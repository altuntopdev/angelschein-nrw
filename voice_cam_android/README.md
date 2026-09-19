# VoiceCam — sesli komutla video kaydı

Tek ekranlık, bağımsız bir Android uygulaması: kamera önizlemesi açık durur,
mikrofonu sürekli dinler ve **“kayıt başlat”** dediğinde video kaydını başlatır,
**“durdur”** dediğinde bitirir. Video `Movies/VoiceCam` klasörüne MP4 olarak
kaydedilir (galeride görünür).

Bu klasör, depodaki Flutter uygulamasından tamamen ayrı bir Gradle projesidir;
Flutter tarafına hiçbir şey eklemez.

## Komutlar

| Ne dersen | Ne olur |
| --- | --- |
| kayıt başlat · kaydı başlat · kayda başla · videoyu başlat · çekimi başlat · başlat | Kayıt başlar |
| kaydı durdur · kayıt durdur · kaydı bitir · durdur · dur · bitir | Kayıt biter, dosya kaydedilir |

İngilizce `start recording` / `stop recording` de çalışır. Eşleştirme Türkçe
karakterleri yok sayar (“Kaydı Başlat” = “kaydi baslat”) ve tam kelime arar,
yani “durum” kelimesi “dur” komutunu tetiklemez. Önce durdurma kelimelerine
bakılır, böylece “kayıt durdur” yanlışlıkla başlatma sayılmaz.

## Mikrofon ikilemi (önemli)

Android’de mikrofonu aynı anda tek uygulama/bileşen kullanabilir. Konuşma tanıma
da, sesli video kaydı da mikrofonu ister. Bu yüzden ekranda bir anahtar var:

- **Kayıt sırasında da dinle (varsayılan, açık):** video **sessiz** kaydedilir,
  mikrofon konuşma tanımada kalır → kaydı sesle de durdurabilirsin. Tam eller
  serbest kullanım budur.
- **Kapalı:** video **sesli** kaydedilir, kayıt boyunca dinleme durur → kaydı
  ekrandaki düğmeyle bitirirsin. Başlatma yine sesle yapılabilir.

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

İlk açılışta kamera ve mikrofon izni sorar. Konuşma tanıma için cihazda bir
tanıma servisi (çoğu telefonda Google uygulaması) kurulu olmalı. İnternetsiz
çalışması için **Ayarlar → Sistem → Diller ve giriş → Sesle yazma → Çevrimdışı
konuşma tanıma** bölümünden Türkçe dil paketini indir — paket kuruluysa tanıma
zaten cihaz üzerinde çalışır, yoksa internet gerekir.

## Nasıl çalışıyor

- `MainActivity.kt` — CameraX önizleme + `VideoCapture`, MediaStore’a kayıt,
  izinler, kayıt sayacı, ekran açık tutma, cihaz yönüne göre video rotasyonu.
- `VoiceCommander.kt` — `SpeechRecognizer`’ı bir döngüde tutar (tanıyıcı her
  cümleden sonra kendini kapattığı için sonuç/hata sonrası yeniden başlatılır;
  hatalarda artan bekleme ile). Kısmi sonuçlara da bakar, böylece komut cümle
  bitmeden çalışır; aynı komut 2,5 saniye içinde tekrar tetiklenmez.
- `VoiceCommands.kt` — konuşma metnini komuta çeviren saf Kotlin kısmı
  (Android’e bağımlı değil), `app/src/test/.../VoiceCommandsTest.kt` ile test
  edilir: `./gradlew test`.

## Sınırlar

- Uygulama ön planda olduğu sürece çalışır. Arka plana alınca mikrofon bırakılır
  ve kayıt sonlanır — arka planda dinleyen bir foreground service bilerek
  eklenmedi (sürekli dinleme pil tüketir ve bildirim gerektirir).
- Sürekli dinleme, tanıma servisini aralıksız çalıştırdığı için pili normalden
  hızlı tüketir.
- Arka kamera kullanılır; ön kameraya geçiş yok.

## Bu ortamda ne doğrulandı

Konteynerde Android SDK yok ve `dl.google.com` ağ politikası ile kapalı, bu
yüzden APK burada derlenemedi. Saf Kotlin komut eşleştirmesi (`VoiceCommands`)
ayrı bir JVM projesine kopyalanıp `VoiceCommandsTest`’teki 5 test çalıştırıldı;
hepsi geçti. Kamera/konuşma tarafı gerçek cihazda denenmelidir.
