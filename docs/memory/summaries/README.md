# Dosya Özetleri

Büyük dosya ve logların 25 satırlık özetleri burada tutulur.

## Kurallar

- Ad: `src/a/x.ts` → `src__a__x.ts.md` (yol ayırıcı `__`).
- İlk satır: `source: <yol> · sha256: <ilk 8 hane> · updated: <YYYY-MM-DD>`.
- Gövde: amaç, yapı, önemli fonksiyonlar (satır no), dış bağımlılıklar, riskler.
- Tam kod veya log yapıştırılmaz. Gizli bilgi yazılmaz.
- Kaynak değişince özet yenilenir; `docs/memory/INDEX.md` satırı güncellenir.

## Ne zaman?

- Dosya 400 satırdan uzunsa veya aynı dosyaya 2+ kez dönülecekse.
- Tek seferlik küçük okumada özet üretmek maliyeti artırır.
