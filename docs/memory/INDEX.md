# Hafıza İndeksi

> Ajan önce bu dosyayı okur. Kaynak dosyayı yalnızca burada özeti yoksa açar.
> Yeni özet eklenince bir satır ekle. Özet en fazla 25 satır olur.

| Kaynak | Özet | Tarih | Durum |
|---|---|---|---|
| — | henüz özet yok | — | — |

## Kullanım

- Özet yolu: `docs/memory/summaries/<yol>__<dosya>.md`
  (`src/a/x.ts` → `src__a__x.ts.md`).
- Özetin ilk satırı: `source: <yol> · sha256: <kısa> · updated: <tarih>`.
- Kaynak değiştiyse hash uyuşmaz; özet yenilenir, satır burada güncellenir.
- Tek seferlik okumada özet üretme; çok turlu işte üret.
