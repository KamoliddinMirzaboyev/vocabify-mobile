# 🚀 Vocabify — Google Play Marketga Chiqarish Bo'yicha To'liq Qo'llanma

Ushbu qo'llanma **Vocabify** ilovasini Google Play Console orqali Play Marketga muvaffaqiyatli, xatosiz va birinchi urinishdayoq tasdiqlatib chiqarish uchun tayyorlandi.

---

## 1. Ilova Identifikatorlari va Texnik Talablar

- **Package Name (Application ID):** `com.vocabify.vocabify_app`
- **Minimum SDK:** `21` (Android 5.0 Lollipop — barcha faol qurilmalarning 99.5%+ qamrovi)
- **Target SDK:** `34`+ (Google Play Store talablariga 100% mos)
- **Build Formati:** `.aab` (Android App Bundle — Play Store faqat AAB qabul qiladi)
- **Bildirishnomalar rejimi:** `inexactAllowWhileIdle` (Google Play ning cheklovchi `SCHEDULE_EXACT_ALARM` ruxsatnomasini talab qilmaydi, tekshiruvdan oson o'tadi).

---

## 2. Release Kaliti (Upload Keystore) Yaratish

Play Store uchun dasturni o'z shaxsiy kalitingiz bilan imzolashingiz kerak. Terminalda quyidagi buyruqni bajaring:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
*Eslatma: Kalit parolini (storePassword & keyPassword) eslab qoling va xavfsiz joyda saqlang!*

### `key.properties` faylini yaratish:
`android/key.properties.example` dan nusxa olib, `android/key.properties` faylini oching:
```properties
storePassword=sizning_parolingiz
keyPassword=sizning_parolingiz
keyAlias=upload
storeFile=upload-keystore.jks
```

---

## 3. Production App Bundle (.aab) Yig'ish

Terminalda loyihaning asosiy papkasida quyidagi buyruqni ishga tushiring:

```bash
flutter build appbundle --release
```

Yig'ilgan fayl quyidagi yo'lda hosil bo'ladi:
```text
build/app/outputs/bundle/release/app-release.aab
```

*Har safar yangi versiya chiqarganingizda `pubspec.yaml` dagi versiya raqamini oshiring (masalan: `version: 1.0.1+2`).*

---

## 4. Google Play Console Sozlamalari (Checklist)

### A. Ilova tafsilotlari (Main Store Listing):
- **Ilova nomi (App name):** `Vocabify: So'z Yodlash & SRS`
- **Qisqa tavsif (Short description, max 80 belgi):**
  > Interaktiv kartalar, interval takrorlash (SM-2) va onlayn so'z janglari.
- **To'liq tavsif (Full description):**
  > Vocabify — xorijiy tillardagi so'zlarni samarali va uzoq muddatli xotirada mustahkamlash uchun zamonaviy yordamchingiz!
  >
  > Asosiy imkoniyatlar:
  > • Ilmiy asoslangan SM-2 interval takrorlash (Spaced Repetition) tizimi;
  > • 3D flip kartochkalar va talaffuzni eshitish (TTS);
  > • Yozma mashqlar (Typing mode) va interaktiv testlar (Quiz);
  > • Real vaqtda boshqa foydalanuvchilar bilan "So'z jangi" (Word Battle);
  > • Kunlik o'rganish statistikasi, qiyin so'zlar tahlili va streak hisobi;
  > • To'liq oflayn ishlash va internet paydo bo'lganda avtomatik sinxronlash;
  > • Excel/CSV yoki matndan so'zlarni ommaviy import qilish.

### B. Grafik aktivlar (Graphics Assets):
1. **Ilova belgisi (App Icon):** 512 x 512 px (32-bit PNG, alfa kanalsiz).
2. **Asosiy reklama banneri (Feature Graphic):** 1024 x 500 px (JPG yoki 24-bit PNG).
3. **Skrinshotlar (Phone Screenshots):** Kamida 4-6 ta skrinshot (16:9 yoki 18:9 nisbatda, masalan 1080 x 2400 px).

### C. Maxfiylik siyosati (Privacy Policy):
Play Console'da `App content` -> `Privacy policy` bo'limiga [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) ning veb havolasini kiriting (masalan, GitHub raw yoki GitHub Pages havolasi).

### D. Ma'lumotlar xavfsizligi (Data Safety Section):
Play Console anketasida quyidagilarni belgilang:
- **Ma'lumotlar to'planadimi?** Ha (Email, foydalanuvchi nomi, o'rganish statistikasi).
- **Uchinchi shaxslarga beriladimi?** Yo'q (reklama tarmoqlari yo'q).
- **Shifrlanganmi?** Ha, barcha ma'lumotlar tranzitda shifrlangan (HTTPS/TLS).
- **Hisobni o'chirish imkoniyati bormi?** Ha, ilova ichida yoki so'rov orqali.

### E. Yosh toifasi (Content Rating):
- IAPP / PEGI / ESRB anketasida so'rovnomani to'ldiring:
  - Zo'ravonlik, behayo so'zlar: Yo'q;
  - Reklama: Yo'q;
  - Natija: **3+ (Barcha yoshdagilar uchun mos)**.

---

## 5. Yangilash va Deploy qilish

Kelgusida yangilanishlarni yuklash:
1. `pubspec.yaml` da versiyani oshirish: `1.0.1+2`
2. `flutter build appbundle --release`
3. Chiqqan `.aab` faylni Google Play Console -> **Production** (yoki **Internal Testing**) bo'limiga yuklash.
