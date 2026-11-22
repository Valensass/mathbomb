# BOMB MATH — Orkestra kuralları

Bu dosya her oturumda okunur; ana oturum bu kurallara uyar.

## Nerede kaldık

Bu görevde Git veya GitHub işlemi yapılmadı; depo durumu doğrulanmadı.
Önceki öneri, kullanıcının kendi terminalinde `codex exec` çalıştırmasını tarif ediyordu.
Yükleme işi açık.
Sonraki adım: proje terminalinde `git --version` ve `gh auth status` çalıştır; uzak geçmişi kontrol et.
Uzak depoda commit varsa force push yapmadan durumu bildir.
Depo boşsa sırları ve APK’ları dışarıda bırakarak yüklemeyi tamamla.

## Memory

Oturum başında varsa önce `docs/CONTEXT.md`, sonra `docs/memory/INDEX.md` okunur. Kaynak dosyaları yalnızca hedefliyse aç; özet varsa ve kaynak değişmediyse özeti kullan. Kalıcı kararları `docs/memory/YYYY-MM-DD.md` dosyasına gerekçesiyle ekle. Büyük dosya özetlerini `docs/memory/summaries/` altında 25 satırı aşmadan tut ve `INDEX.md`'yi güncelle. Gizli bilgi hafızaya yazılmaz.

## Proje

Flutter/Dart ile yazılmış Android oyunu; paket `com.valensass.bomb_math`.

| Yol | İçerik |
| --- | --- |
| `lib/core/` | Tema, yerelleştirme (EN/TR), ses havuzu, titreşim |
| `lib/game/` | Soru üretici, solo ve düello motorları, bot, madalyalar |
| `lib/data/` | Modeller, kalıcılık, profil, istatistik ve ayar durumu |
| `lib/services/` | WebSocket çok oyunculu istemci |
| `lib/ui/` | Ekranlar, cevap tuş takımı, bomb çizimi, FX ve sheet’ler |
| `server/` | Dart (shelf + WebSocket) maç sunucusu |
| `tool/` | Ses sentezi, çok oyunculu duman testi, bot |
| `test/` | Birim ve widget testleri |
| `docs/` | `GAME_DESIGN.md`, raporlar, ekran görüntüleri |

## Komutlar

- `flutter analyze` — statik analiz; hedef sıfır issue.
- `flutter test` — tüm testler.
- `dart run tool/mp_smoke_test.dart` — yalnızca sunucu veya çok oyunculu akış değiştiğinde.
- İlk GitHub yüklemesinden önce kimlik doğrulamasını ve uzak geçmişi doğrula.

## Kurallar

- Kod, yorum ve dokümanlar İngilizce; kullanıcıya rapor Türkçe.
- Oyun davranışı değişince `docs/GAME_DESIGN.md` güncellenir.
- Yeni arayüz metinleri `lib/core/l10n.dart` içine İngilizce ve Türkçe eklenir.
- Durum yönetiminde Provider ve `AppState` kullanılır; motorlar saf Dart ve tohumla deterministik kalır.
- Sesler `tool/synth_audio.py` ile üretilir; üçüncü taraf oyun varlığı eklenmez.
- Yeni paket veya bağımlılık eklemek için kullanıcı onayı gerekir.
- Sırlar (API anahtarı, keystore, parola, `.env`, kimlik bilgisi) sohbete, koda veya loga yazılmaz.
- Yayımlama öncesi gizli dosyaların ve yapı klasörlerinin stage alanında olmadığını doğrula.
- `dist/` içindeki APK’ları yayımlamada varsayılan olarak hariç tut.
- Uzak depo erişimi veya durumu doğrulanamıyorsa bunu açıkça bildir; uzak geçmiş varken force push yapma.
- Tehlikeli Git işlemleri yasak: `reset --hard`, `rebase`, `stash`, `push --force`. Kullanıcı istemeden commit yapma.
- Erişilemeyen dosya veya API için doğrulanmadığını belirt.
- Çalıştırılmayan test veya analizi başarılı diye bildirme.
- Sunucu LAN/duman testi içindir; TLS, kimlik doğrulama veya cevap doğrulaması sağladığını varsayma.
- Kullanıcı istemeden uzun işler (release build, yayın) çalıştırma.

## Çalışma düzeni

- Ana oturum işi koordine eder; dar kapsamı ve dosya sahipliğini belirler.
- Alt ajanları yalnızca kullanıcı veya geçerli proje yönergeleri açıkça istediğinde kullan.
- Brif; görevi, izinli dosyaları, ön okumayı, bitiş koşulunu ve raporu belirtir.
- Son raporda yapılanları, değişen dosyaları, doğrulamayı ve açık konuları belirt.
- Çalışma sonunda ağacı derlenebilir durumda bırak.

## Salt okunur çalışma

Salt okunur oturumda dosya değiştirme; yalnızca incele ve raporla.
