# İçerik boru hattı (content pipeline)

Bu klasör, uygulamanın soru bankası ve sözlük içeriğinin ham kaynağını ve buradan otomatik olarak
üretilen yapılandırılmış (structured) verileri barındırır.

## Resmi NRW sınav kuralları (doğrulanmış, 2026-08-27)

Kaynak: [Fischerprüfungsordnung NRW, § 5 ve § 6](https://recht.nrw.de/lrgv/rechtsverordnung/01012015-verordnung-ueber-die-fischerpruefung-fischerpruefungsordnung/)
(resmi yönetmelik metni, recht.nrw.de).

- Resmi soru havuzu **359 soru**, 6 konu alanına dağılmış (bizim ayrıştırdığımız 335 kullanılabilir
  soru bu havuzun bir alt kümesi — her kategori sınav için gereken 10'un üzerinde olduğu için
  eksiksiz değil ama fonksiyonel olarak yeterli).
- Sınav **60 soru**, her kategoriden **10 soru** — uygulamadaki `buildMockExam()` zaten buna uygun.
- **Süre: 60 dakika** — uygulamada quiz ekranına geri sayım sayacı olarak eklendi (`QuizScreen.timeLimit`).
- **Geçme kriteri (§ 6 Abs. 2):** en az **45/60** doğru VE her kategoriden en az **6/10** doğru.
  Önceki tahminimiz (%85 + kategori başı en fazla 2 yanlış) **yanlıştı**, düzeltildi
  (`quiz_result_screen.dart`).
- Gerçek sınavda ayrıca bir **pratik bölüm** (ekipman/malzeme tanıma) ve **balık türü tanıma** kısmı
  da var (§ 6 Abs. 2) — bu uygulama sadece yazılı/teorik kısmı kapsıyor, bu net bir kapsam sınırı.

## Kaynak (`source/`)

- `NRW Angelschein Türkçe_Almanca Soruları - ETAC - Avrupa Olta Balıkçıları.pdf` — Ömer Altuntop
  (OltaTv / Avrupa Olta Balıkçıları) tarafından hazırlanmış, NRW Fischereiprüfung soru bankasının
  Almanca–Türkçe açıklamalı çevirisi. **Telif hakkı yazara ait; kullanım izni bizzat yazardan
  sözlü/yazılı olarak alındığı teyit edilmiştir (2026-08-27).** Yazarın notuna göre bu doküman
  "bitmemiş, ham hali" (taslak) — bazı sorularda tutarsızlıklar bu yüzden bekleniyor.
- `Almanca_Türkçe OLTA BALIKÇILIĞI SÖZLÜĞÜ - ETAC_Avrupa Olta Balıkçıları.pdf` — aynı yazarın
  Almanca–Türkçe–Latince balıkçılık terimleri sözlüğü. Aynı telif/izin durumu geçerli.

## Ayrıştırma scriptleri (`scripts/`)

PDF'lerdeki metin, PyMuPDF ile karakter/renk/konum bilgisiyle (`get_text("dict")`) ayrıştırılıyor —
düz `pdftotext` çıktısı kullanılmadı çünkü (a) "fi"/"fl" ligatürlerini siliyordu (örn. "Flossen" →
"ossen") ve (b) çok sütunlu sayfa düzenini satır satır karıştırıyordu.

- `parse_questions.py <pdf> <out.json>` — soru bankasını ayrıştırır.
  - **Doğru cevap tespiti:** kaynak PDF'te doğru şık, metin rengi `RGB(0,143,0)` (yeşil) ile
    işaretlenmiş — bunu tespit ederek `correct: true/false` alanını otomatik dolduruyoruz.
  - **Mini-not tespiti:** bazı sorularda Türkçe cevabın altında "Açıklama:" ile başlayan bir not
    var — bunu ayrı bir `note` alanına çıkarıyoruz (kullanıcının istediği "mini-not" özelliği için).
  - Bir dilde işaretleme eksikse ve diğer dilde tek bir yeşil şık varsa, doğru harfi karşı dilden
    ödünç alıyoruz (`correct_source: "borrowed_from_tr/de"`) — şıkların sırası (a/b/c) her iki dilde
    de aynı olduğu için güvenli.
- `parse_glossary.py <pdf> <out.json>` — 3 sütunlu (Almanca / Türkçe / Latince) sözlük tablosunu
  sütun x-konumu + satır y-kümeleme ile satırlara ayırır.

## Üretilen veri (`parsed/`)

- `questions.json` — `{"questions": [...], "unresolved_extra": [...]}`. Her soru:
  `{category, number, de: {question, options:[{letter,text,correct}], note, page}, tr: {...}}`.
  **342 soru, 6 resmi kategoriye dağılmış** (bkz. aşağıdaki sayılar). Otomatik ayrıştırma
  kalite kontrolünden %98'in üzerinde temiz geçti; kalan ~8 soru elle incelenmeli (aşağıya bakın).
- `glossary.json` — `[{de, tr, lat, page}]` satır listesi. 235 satır ayrıştırıldı, 216'sı temiz
  eşleşti, 19'u (çoğunlukla sayfa numaraları + birkaç serbest-metin dipnot) `orphan: true` ile
  işaretli ve tabloya doğrudan eşlenemedi.

## Kategori dağılımı (mevcut ham veri)

| Kategori | Soru sayısı |
|---|---|
| Allgemeine Fischkunde | 51 |
| Spezielle Fischkunde | 70 |
| Gewässerkunde und Fischhege | 76 |
| Natur- und Tierschutz | 42 |
| Gerätekunde | 38 |
| Gesetzeskunde | 65 |

Not: sınavın kendisi her kategoriden 10 soru çekiyor (60 soruluk mock sınav) — dolayısıyla her
kategoride en az 10 sağlam soru olması yeterli; şu an hepsi bunun oldukça üzerinde.

## Elle incelenmesi gereken sorular (~8 adet)

1. **allgemeine_fischkunde #11** — ne Almanca ne Türkçe tarafında yeşil işaret yok (kaynakta
   unutulmuş). Soru: "Balıklarda hangi yüzgeç çift olarak bulunur?" → biyolojik olarak doğru cevap
   muhtemelen **c) Göğüs Yüzgeci** (pektoral yüzgeçler çifttir) ama resmi kaynakla teyit edilmeli.
2. **allgemeine_fischkunde #33** — Almanca şıkları PDF'te tek satıra sıkışmış
   ("a) X b) Y c) Z"), ayrıştırıcı bunu 3 ayrı şıkka bölemedi. Türkçe tarafı temiz (cevap: a).
   Elle düzeltilebilir, kolay.
3. **geraetekunde #26** — Almanca soru metni kaynak PDF'te hiç yok, sadece Türkçe var
   (cevap: b, Spinner ile Blinker farkı).
4. **gesetzeskunde #41** — yazar tarafından **iptal edilmiş** ("entfällt" / "Bu soru iptal edildi").
   Soru bankasına dahil edilmemeli.
5. **gewaesserkunde_und_fischhege #76** — yazarın kendi notuna göre bu, 75. sorunun **yanlışlıkla
   iki kez yazılmış hali**. Almanca+cevap (b) kullanılabilir, Türkçe metin olarak 75. sorunun
   çevirisi tekrar kullanılabilir.
6. **spezielle_fischkunde #58** — ne Almanca ne Türkçe tarafında yeşil işaret yok. Soru: "Hangi
   balıklar Morina Balıkları (Dorschartige) ailesindendir?" → muhtemelen **a) Morina, Tatlısu
   Gelinciği, Kömür Balığı** ama teyit gerekli.
7. **spezielle_fischkunde #59** — Türkçe çevirisi kaynak PDF'te hiç yok, sadece Almanca var
   (cevap: c, Freiwasserfische).

Bu liste küçük ve somut — ya Ömer Altuntop'a sorup teyit alınabilir, ya da resmi
Landesfischereiverband NRW kaynağıyla karşılaştırılabilir. Uygulamanın ilk sürümü için bu 8 soru
soru bankasından geçici olarak çıkarılıp kalan 334 soru ile başlanabilir.

## Almanca sözlük tanımları (`assets/data/glossary_de.json`)

"Almanca biliyorum" (fluent) kullanıcılar için sözlükte Türkçe çeviri yerine gerçek bir Almanca
tanım gösteriliyor (örn. "Karpfen: Ein häufiger Süßwasserfisch mit hohem Körper, gehört zu den
Karpfenfischen."). Bu tanımların 212 tanesi **tarafımdan (Claude) yazıldı** — kaynak PDF'te
Almanca tanım/açıklama metni yoktu, sadece Türkçe çeviri vardı. Üretim scripti:
`AppData/Local/Temp/.../scratchpad/build_de_definitions.py` (proje dışı, scratchpad'te) —
`content/parsed/glossary.json`'daki sıraya index ile eşleşiyor (string key değil), böylece OCR
kaynaklı yazım farklarından etkilenmiyor. Bu, sınav sorusu/cevabı gibi doğruluğu kritik bir içerik
değil — genel balıkçılık terminolojisi tanımları; yine de gözden geçirilmesi faydalı olur.

## Sözlükte gözden geçirilecekler

19 "orphan" satırın çoğu sayfa altı numaraları (gürültü, atılabilir); birkaçı ise tam sayfa
genişliğinde serbest-metin dipnotlar (örn. Blankaal göç açıklaması, alg patlaması/ötrofikasyon
açıklaması, "Jugendfischereischein" açıklaması) — bunlar hangi terime ait olduğu belli olacak
şekilde elle ilgili sözlük satırına not olarak eklenmeli.
