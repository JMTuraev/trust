# Trust — Play Console'ni yakunlash (qolgan qadamlar + aniq qiymatlar)

> Holat: 2026-07-20. Ilova Play Console'da **yaratildi**, store listing **matni** kiritildi (ru-RU, qoralama).
> Quyida faqat qolgan ishlar — aniq qiymatlar bilan. Batafsil forma savollari: `docs/play-store-checklist.md`,
> `docs/data-safety.md`, `docs/ai-content-compliance.md`.

App: **Trust — Oldi-berdi daftari** · paket `uz.trust.trust_mobile` · asosiy til **ru-RU**
(Play'da o'zbek "default language" yo'q; listing matni `docs/store-listing-ru.md` da).

---

## ✅ Bajarildi
- Play Console'da ilova yaratildi (Bepul, Play App Signing yoqilgan).
- Store listing MATNI kiritildi va saqlandi: nom, qisqa tavsif (76/80), to'liq tavsif (~2641/4000) — hammasi ru-RU.
- Reviewer test-login **bypass kodi** yozildi: `src/config.js`, `src/services/otp.js`, `render.yaml` (env-gated).
- Store assetlari yaratildi: `docs/store-screenshots/store-icon-512.png` (512×512), `feature-graphic.png` (1024×500).
  Skrinshotlar allaqachon bor: `docs/store-screenshots/01-hub.png … 05-trust.png` (1080×1920).

---

## 1) Reviewer bypass'ni DEPLOY qilish  🔴 (busiz review "kira olmadik" deb rad etadi)
Sandbox `.git`dan push qila olmadim — buni siz qilasiz:
```
cd /d D:\trust
git add src/config.js src/services/otp.js render.yaml
git commit -m "feat(auth): store-review test-login bypass (env-gated)"
git push origin main
```
So'ng **Render Dashboard → trust-backend → Environment** ga:
- `REVIEW_TEST_PHONE` = `998900000000`
- `REVIEW_TEST_CODE`  = `50413`

Deploy tugagach tekshiring (test — ilovada yoki curl):
`+998 90 000 00 00` raqami → kod `50413` → kirish ochilishi kerak (SMS kelmaydi).
Ilovani QAYTA QURISH shart emas (mavjud AAB shu bilan ishlaydi).

## 2) Privacy policy — GitHub Pages  🔴
GitHub → repo **JMTuraev/trust** → Settings → Pages → Source: `main` / papka `/docs` → Save.
Bir necha daqiqada URL tayyor:
**https://jmturaev.github.io/trust/privacy-policy.html**
Bu URL'ni Play → App content → Privacy policy ga kiriting.

## 3) Store listing — GRAFIKA (matn tayyor, faqat rasmlar qoldi)
Play → Grow → Store presence → Main store listing (ru-RU), "Графика" bo'limi. Har slotga sudrab tashlang:
- **Значок (icon 512×512):** `docs/store-screenshots/store-icon-512.png`
- **Изображение функции (feature 1024×500):** `docs/store-screenshots/feature-graphic.png`
- **Скриншоты телефона (≥2, bor 5):** `docs/store-screenshots/01-hub.png … 05-trust.png`
Keyin **Сохранить**.

## 4) AAB'ni Internal testing'ga yuklash  🔴
Play → Testing → Internal testing → (ochilgan) "Создать выпуск" → App Bundle'ni sudrab tashlang:
`D:\trust\mobile\build\app\outputs\bundle\release\app-release.aab` (16.7MB, imzolangan, arm64).
Release notes yozib, testerlar ro'yxatini tanlab saqlang.

## 5) App content formalari  🔴
`docs/play-store-checklist.md` va `docs/data-safety.md` bo'yicha:
- **Data safety:** Collected=Yes, Encrypted in transit=Yes, Deletion=Yes;
  Telefon (Shared: SMS provayder), Ism (No), Moliyaviy ma'lumot + AI xabarlari **Shared=Yes (Anthropic)**.
  Audio/ovoz — **BELGILANMAYDI** (mikrofon yo'q).
- **Content rating (IARC):** Utility/Finance; zo'ravonlik/kontent — No; foydalanuvchilararo aloqa — No;
  AI-generated content — Yes (moderatsiya: system-prompt + in-app flag).
- **Target audience:** **18+**; bolalar uchun emas.
- **App access:** "All or some functionality restricted" → test kirish:
  **Telefon: +998 90 000 00 00 · Kod: 50413 · SMS kelmaydi, kod doimiy (review test-akkaunti).**
- **Ads:** reklama yo'q (ilova reklama ko'rsatmaydi) — mos belgilang.
- Financial/Government/Health deklaratsiyalari — checklist bo'yicha.

## 6) Review'ga yuborish
Internal testda tekshirilgach → Production (yoki avval internal) → **Обзор публикации → Отправить на проверку**.
(Men bu yakuniy qadamni sizsiz bosmayman — tasdiqlaganingizda birga yuboramiz.)

---

### Reviewerga beriladigan test-login (App access)
```
Telefon: +998 90 000 00 00
Kod (OTP): 50413
Izoh: test akkaunti, SMS yuborilmaydi, kod doimiy.
```

### Ochiq (huquqiy/PO) — checklist §8
O'zbekiston shaxsiy ma'lumotlar qonuni + Anthropic'ga uzatish (DPA/SCC) — huquqshunos tasdig'i.
