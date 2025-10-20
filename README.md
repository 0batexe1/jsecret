
---

````markdown
# jsecret — Gelişmiş Secret / Sensitive Extractor

Basit, taşınabilir bir Bash aracı: büyük JS bundle'ları veya diğer statik dosyaları tarayıp potansiyel gizli bilgileri (API anahtarları, token'lar, private key blokları, DB bağlantıları vb.) bulur. Hem yerel dosya hem de URL girişi desteklenir; base64/base64url decode ile obfuscation'ı açar; ham (cleartext) bulguları kaydeder.

---

## ⚠️ ÖNEMLİ (UYARI)

Bu araç hassas verileri HAM (cleartext) olarak disk üzerine yazar. Çıktıları güvenli bir yerde saklayın ve yetkisiz kişilerle paylaşmayın. Aracı **sadece** şu amaçlarla kullanın:

- Kendi projeleriniz,
- Kurumunuzun izniyle gerçekleştirilen taramalar,
- veya açıkça izin verilmiş bug bounty hedefleri.

İzinsiz tarama yasal sorunlara yol açabilir.

---

## İçindekiler

Aşağıda README içerisindeki başlıkları hızlıca görebilirsiniz:

- Özellikler  
- Gereksinimler  
- Kurulum  
- Kullanım Örnekleri  
- Çıktı Dosya Yapısı  
- `--diff` Modu (Farklama)  
- Gelişmiş İpuçları ve Hatalar  
- Güvenlik ve Etik  
- Katkı (Contribution)  
- Lisans ve `.gitignore` önerisi  
- Sık Sorulan Sorular (SSS)

---

## Özellikler

Bu bölüm script'in temel özelliklerini açıklar.

- Tek dosya veya `targets.txt` (çoklu hedef) ile tarama.
- URL indirimi (akıllı dosya adı çıkarma).
- Base64 / Base64URL decode ile obfuscation çözümü.
- Geniş regex seti: AWS, Google, Stripe, Slack, SendGrid, Mailgun, GitHub tokenları, OAuth token'lar, session id'ler, e-posta, telefon, PEM/SSH private key blokları, DB connection string'leri, Basic auth vb.
- Ham `_raw.txt` ve `_context.txt` (satır numarası + satır) çıktıları.
- `onceki_bulgular/` altında tarihlenmiş kayıt saklama.
- `--diff=true` ile önceki taramayla fark çıkarma.
- Tamamen Bash ile yazıldı — taşınabilir ve bağımsız (sadece yaygın CLI araçlarına ihtiyaç var).

---

## Gereksinimler

Bu script'i çalıştıracak makinede aşağıdaki araçların bulunması önerilir:

- `bash` (POSIX uyumlu)  
- `grep` (GNU grep önerilir; PCRE desteği için `grep -P`)  
- `curl`  
- `base64`  
- `sort`, `sed`, `awk`, `comm`, `stat`, `cp`, `mv`, `printf`

> Not: Eğer sisteminizde `grep -P` yoksa script fallback ile çalışır ancak `grep -P` bulunması regex uyumluluğunu artırır.

---

## Kurulum

Bu bölüm script'i repoya ekleme ve çalıştırma adımlarını gösterir.

1. Script dosyasını repoya kopyalayın veya repoda oluşturun.
2. Çalıştırılabilir hale getirin.

Aşağıdaki komutları kullanabilirsiniz:

```bash
# repodan dosyayı kopyala (veya doğrudan repoya ekle)
cp jsecret.sh /path/to/repo/

# çalıştırma izni ver
chmod +x jsecret.sh
````

---

## Kullanım Örnekleri

Bu bölümde en yaygın kullanım senaryoları bulunur. Her örneğin altında kısa açıklama vardır.

**Tek dosya (yerel):** script'e yerel bir JS veya dosya verirsiniz. Script dosyayı kopyalayıp tarar.

```bash
./jsecret.sh bundle.js
```

**Tek URL (script indirir):** script URL'yi indirir ve üzerinde tarama yapar.

```bash
./jsecret.sh https://example.com/_nuxt/abcd1234.js
```

**Targets listesi (çoklu hedef):** `targets.txt` dosyasında her satıra bir hedef koyun (URL veya yerel dosya).

```
# targets.txt örnek içeriği
https://example.com/_nuxt/abcd1234.js
./local_bundle.js
```

```bash
./jsecret.sh targets.txt
```

**Diff modu (sadece yeni bulunan öğeler):** önceki taramalarla karşılaştırma yapar; yeni bulunan öğeleri kaydeder.

```bash
./jsecret.sh targets.txt --diff=true
```

Script çalıştırıldığında yeni bir çıktı klasörü otomatik olarak oluşturulur: `bulgular_<YYYY-MM-DD_HH-MM-SS>/`

---

## Çıktı Dosya Yapısı

Tarama tamamlandığında `bulgular_<timestamp>/` içinde aşağıdaki dosya ve klasörler oluşur. Her birinin ne olduğu kısaca açıklanmıştır.

* `orijinler/` — indirilen veya kopyalanan orijinal dosyalar.
* `tum_input_birlesik.js` — tarama için birleştirilmiş içerik (indirilen dosyalar + decode edilen içerikler).
* `*_raw.txt` — bulunan ham eşleşmeler (cleartext) — her pattern için ayrı dosya.
* `*_context.txt` — eşleşmenin satır numarası ve satır içeriği (triage için).
* `decoded_extra.txt` — base64/base64url'den decode edilen içerikler (varsa).

Örnek dosya isimleri: `google_api_raw.txt`, `stripe_pk_raw.txt`, `jwt_raw.txt`, `email_raw.txt` vb.

---

## `--diff` Modu (Farklama)

`--diff=true` parametresi ile script, `onceki_bulgular/` klasörü içindeki en son kaydı bulur ve yeni run ile fark alır. Yeni bulunan öğeler `*_yeni.txt` şeklinde kaydedilir.

**Kullanım örneği:**

```bash
./jsecret.sh targets.txt --diff=true
```

**Nasıl çalışır (kısa):**

* Script `onceki_bulgular/` içindeki en son klasörü bulur.
* Her pattern için yeni ve eski `_raw.txt` dosyalarını `comm -23` ile karşılaştırır.
* Sadece yeni bulunan satırlar `*_yeni.txt` içinde toplanır.

---

## Gelişmiş İpuçları ve Hatalar

Aşağıda sık karşılaşılan durumlar ve öneriler var:

* **`binary file matches` uyarısı alırsanız:** script, dosyaları text biçiminde taramak için `grep -a` gibi seçenekleri kullanır; yine de sistemdeki `grep` sürümünü (GNU önerilir) kontrol edin.
* **Minify edilmiş büyük JS’lerde hiçbir şey bulunmuyorsa:** bu, dosyada gerçekten gizli bilgi olmadığı veya hassas verilerin sunucu tarafında (backend) tutulduğunu gösterebilir.
* **False-positive (yanlış pozitif) olasılığı:** regex’ler geniş tutulmuştur; hızlı triage için `*_context.txt` dosyalarını kullanın.
* **Daha fazla decode gerekli ise:** hex decode, unicode-unescape, rot13, basit XOR vb. deşifre yöntemleri ekleyebilirsiniz. Bu tür gelişmiş deobfuscation'lar `jsecret.sh` içine kolayca eklenebilir.
* **Performans:** çok büyük bundle’lar için önceden `prettier` veya `js-beautify` ile formatlamak arama doğruluğunu artırabilir ancak genelde script mevcut haliyle binary-safe tarama yapar.

---

## Güvenlik ve Etik

* Bu aracı **sadece izin verilen** hedeflerde kullanın.
* Bulduğunuz hassas bilgileri üçüncü taraflarla paylaşmayın.
* Zafiyet bildiriminde bulunurken hedefin resmi güvenlik iletişim kanallarını kullanın.
* Çıktı dosyalarını gizli tutun veya şifreleyin.

---

## Katkı (Contribution)

* PR'ler, issue'lar ve öneriler memnuniyetle karşılanır.
* Değişiklik yaparken test verilerinin anonim olmasına dikkat edin; gerçek secret içermesin.
* Kod stiline uygun, küçük ve test edilebilir PR'lar tercih edilir.

---

## Lisans ve `.gitignore` önerisi

Önerilen lisans: **MIT** (veya tercih ettiğiniz açık kaynak lisansı). Repoya eklemeyi unutmayın.

Örnek `.gitignore`:

```
/bulgular_*
/onceki_bulgular/
/*.log
```

---

## Sık Sorulan Sorular (Kısa)

**S: `tum_input_birlesik.js` ne işe yarıyor?**
C: Tüm girdiler (indirilen dosyalar + decode edilen içerik) tek bir dosyada birleştirilir; taramalar tek dosya üzerinde çalıştırılır. Bu, tek noktadan grep/regex çalıştırmayı kolaylaştırır.

**S: Context dosyaları neden var?**
C: Eşleşmenin dosyada nerede olduğunu ve hangi satır çevresinde göründüğünü gösterir — triage ve false-positive eleme için faydalıdır.

**S: `--diff=true` nasıl çalışır?**
C: `onceki_bulgular/` içindeki en son klasöre bakar ve `comm -23` ile yalnızca yeni öğeleri çıkarır.

---

## İletişim

Repo ile ilgili sorunlar, geliştirme önerileri veya güvenlik raporları için GitHub Issues kullanabilirsiniz. Gerçek hassas bulgular için hedefin resmi sorumluluk açıklama / güvenlik kanallarını tercih edin.

---
