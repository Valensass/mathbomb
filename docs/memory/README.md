# Hafıza

Bu klasör, oturumlar arasında taşınacak kalıcı bilgiyi tutar. Amaç, kaynak dosyayı
tekrar tekrar okumak yerine kısa özetten devam etmektir.

## Kurallar

- Kararlar: `YYYY-MM-DD.md` dosyasına tarih ve gerekçeyle ekleme yap (append-only).
- Dosya özetleri: `summaries/<dosya-adı>.md`, en fazla 25 satır.
- Özet varken kaynağı yeniden okuma; kaynak değiştiyse özeti güncelle.
- Token, parola, anahtar ve kişisel veri yazma.
- Geçici durum (çalışan komut, açık oturum) buraya değil, görev yanıtına yazılır.

## Ne zaman yazılır?

- Mimari veya davranış kararı verildiğinde.
- Bir dosya/log ilk kez özetlendiğinde.
- Aynı bilgi ikinci kez sorulduğunda (tekrar okumayı önlemek için).
