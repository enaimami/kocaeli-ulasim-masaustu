# Kocaeli Ulaşım — masaüstü

Kocaeli'deki otobüs/tramvay bilgisini gösteren, kişisel kullanım için yazılmış küçük bir
masaüstü uygulaması. Aynı adlı Android uygulamasının KDE Plasma için yerel sürümüdür:
C++20 + Qt 6 (Qt Quick, Qt Location) + Kirigami. Electron/Tauri yok.

## Bu ne, ne değil?
Basit bir şey: durağa hangi aracın kaç dakikada geleceğini, hat duraklarını ve saatlerini,
haritada durakları gösterir; istersen araç yaklaşınca bildirim verir. Hepsi bu.
Resmî bir uygulama değildir; kart, bakiye, ödeme ya da hesap işlemi **yoktur**. Yalnızca
herkese açık, giriş gerektirmeyen veriyi okur ve sunucuyu yormamak için istekleri seyrek
tutar (yalnızca pencere açıkken, 20 sn'de bir, sırayla).

## API uçlarını nasıl bulduk?
KentKart'ın herkese açık bir belgesi yok. Uçları şöyle çıkardık:
1. **Resmî mobil uygulamaya bakarak:** MobilKentkart Android uygulaması React Native ile
   yazılmış; APK'nın içindeki JavaScript paketinde (Hermes) servis adresi
   (`https://service.kentkart.com/rl1/`) ve uç adları (`stop/closest`, `bus/closest`,
   `route/list`, `route/info`, `announce` …) düz metin olarak duruyor.
2. **Elle deneyerek:** her ucu tarayıcı/komut satırından tek tek çağırıp hangi
   parametrelerin zorunlu olduğunu (pratikte yalnızca `region=004`, Kocaeli) ve yanıtların
   biçimini gördük. Giriş gerektiren uçlara (kart, ödeme, hesap) bilinçli olarak dokunmadık.
3. **Uygulamayı yazarken düzelterek:** beklenmedik yanıtlar (ör. sonuç yoksa `code: 3`
   "Sonuç Bulunamadı") çıktıkça notlara ve koda işledik. Gerçek yanıt örnekleri
   `tests/fixtures/` altında; testler bunlarla çalışır.

API değişirse uygulama bozulabilir; o zaman `src/KentKart.cpp`'deki dönüşümler güncellenmeli.

## Özellikler
- **Ana sayfa:** hat/durak arama (hatlar istemcide, durak adı sunucuda ≥ 3 harf), son aramalar,
  etkin takipler, duyurular (Ayarlar'dan açılır), favori duraklar (yaklaşan araçlarıyla, 30 sn),
  favori hatlar, yakındaki duraklar.
- **Durak:** yaklaşan canlı araçlar (20 sn'de bir, yalnızca pencere görünürken), "Haber ver",
  bu duraktan geçen hatlar + planlı sonraki sefer, "bu hat gelince haber ver".
- **Hat:** yön değiştirme, duraklar (hat renginde çizgi, duraktaki araçlar, "Takip et"),
  saatler (yaklaşan + gün tipine göre tam tarife), harita (güzergah, duraklar, canlı araçlar).
  Ağ yoksa son görülen hat bilgisi çevrimdışı gösterilir.
- **Harita:** OpenStreetMap karoları; kaydırınca çevredeki duraklar, durak önizleme kartı.
  Koyu temada karolar gölgelendiriciyle karartılır.
- **Varış takibi:** en çok 5; durağa N durak kala / varışta / seçilen noktaya yaklaşınca.
  Bildirim ya da alarm (kritik bildirim + durdurulana kadar ses). Pencere kapatılınca tepside sürer.
- Tek örnek: ikinci kez açınca mevcut pencere öne gelir.

## Derleme ve kurulum
Yazı tipleri `data/fonts/` altında gelir:
- `InterVariable.ttf` — Inter, SIL Open Font License (`data/fonts/OFL.txt`).
- `symbols.ttf` — Material Symbols Rounded'ın (Google, Apache 2.0) yalnızca kullanılan
  simgelere kırpılmış hâli. Simge eklemek için: AUR `ttf-material-symbols-variable` kur,
  `tools/subset_symbols.py`'deki ICONS'a ekle, `python3 -I tools/subset_symbols.py` (fontTools gerekir).

```bash
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=$HOME/.local
cmake --build build -j8
./build/tests                 # mantık testleri (fixture'lar tests/fixtures)
cmake --install build         # ~/.local/bin + menü girdisi + simge
```
Komut satırı: `kocaeli-ulasim [--sayfa ana|harita|takipler|ayarlar] [--durak KİMLİK] [--hat KOD]`.

Gerekenler (Arch): `qt6-base qt6-declarative qt6-location qt6-positioning qt6-multimedia
qt6-shadertools kirigami kirigami-addons kstatusnotifieritem kdbusaddons`. Konum için `geoclue`
(yoksa son bilinen konum / İzmit merkezi kullanılır).

## Yapı
- `src/KentKart.*` — API istemcisi ve yanıt dönüşümleri (yalnızca public GET, region=004).
- `src/Text.*` — Türkçe arama normalizasyonu, hat dizini.
- `src/TrackingLogic.*` — takip mantığı (Android `Tracking.kt` karşılığı, testli).
- `src/Tracker.*` — yoklama turları (sıralı, 20/60 sn), kalıcı kayıt.
- `src/Notifier.*` — freedesktop bildirimleri, alarm sesi.
- `src/Api.*`, `RouteCatalog.*`, `Store.*` — QML singleton'ları.
- `qml/` — arayüz. `shaders/darkmap.frag` — koyu harita.

Veri: `~/.local/share/kocaeli-ulasim/` (favoriler/ayarlar `store.json`, takipler, hat önbelleği),
karo önbelleği `~/.cache/kocaeli-ulasim/tiles`.
