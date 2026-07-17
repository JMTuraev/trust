# Trust AI — birinchi foydalanish roziligi (consent copy)

> Status: **normativ matn** (2026-07-17). Bu ekran Trust AI birinchi ochilganda **bir marta**
> ko'rsatiladi. Google Play 2026-07-15 User Data talabi: uchinchi tomon AI integratsiyasi uchun
> **disclosure + consent** developer zimmasida.
> Bog'liq: `docs/privacy-policy.html` §3, `docs/play-store-checklist.md` §2a.

## Qoidalar (dizayn/mahsulot)

1. **Bir marta**, AI tabi birinchi ochilganda. Rozilik berilmaguncha `POST /api/ai/chat` chaqirilmaydi.
2. **Rad etish yo'li SHART** — «Hozir emas» tugmasi. Rad etilsa ilovaning qolgan qismi
   (qarz, xarajat, hisob-kitob) **to'liq ishlaydi**. AI — ixtiyoriy funksiya.
3. Rozilik **qaytarib olinadi**: Profil → Trust AI → o'chirish. Keyin AI tabi yana shu ekranni ko'rsatadi.
4. Matn **halol va sodda** — «anonim» yoki «hech narsa saqlanmaydi» kabi noto'g'ri va'da YO'Q.
5. Maxfiylik siyosatiga havola (§3) bosiladigan bo'lsin.

---

## O'zbekcha (asosiy)

**Sarlavha:** Trust AI — ma'lumotlaringiz haqida

**Matn:**

> Trust AI savolingizga javob berish uchun moliyaviy ma'lumotlaringizning **umumlashtirilgan
> xulosasini** (oylik daromad/xarajat jami, toifalar, qarz summalari) va siz yozgan xabarni
> tahlil uchun **Anthropic** kompaniyasining sun'iy intellekt xizmatiga yuboradi.
> Hamkorlaringizning **haqiqiy ismlari yuborilmaydi** — ular serverda `HAMKOR_1` kabi taxallusga
> almashtiriladi va javob qaytgach qurilmangizda tiklanadi. Har bir yozuvingiz alohida emas,
> faqat umumiy raqamlar ketadi.
> AI xato qilishi mumkin va u **moliyaviy maslahatchi emas** — har javob ostidagi tugma orqali
> noto'g'ri javob haqida bizga xabar bering.

**Tugmalar:**
- Asosiy: **Roziman, boshladik**
- Ikkilamchi: **Hozir emas**
- Havola: **Maxfiylik siyosati**

**Rad etilganda (toast/ekran):**
> Mayli — Trust AI o'chiq qoladi. Ilovaning qolgan qismi odatdagidek ishlayveradi.
> Fikringiz o'zgarsa, AI tabidan yoqasiz.

---

## Ruscha (ru)

**Заголовок:** Trust AI — о ваших данных

**Текст:**

> Чтобы ответить на ваш вопрос, Trust AI отправляет **обобщённую сводку** ваших финансов
> (суммы доходов/расходов за месяц, категории, суммы долгов) и текст вашего сообщения в
> сервис искусственного интеллекта компании **Anthropic**.
> **Настоящие имена ваших контрагентов не отправляются** — на сервере они заменяются на
> псевдонимы вида `HAMKOR_1` и восстанавливаются на вашем устройстве после ответа.
> Отдельные записи не передаются — только общие цифры.
> ИИ может ошибаться и **не является финансовым консультантом** — сообщайте о неверных
> ответах кнопкой под каждым сообщением.

**Кнопки:**
- Основная: **Согласен, начнём**
- Вторичная: **Не сейчас**
- Ссылка: **Политика конфиденциальности**

**При отказе:**
> Хорошо — Trust AI останется выключенным. Остальная часть приложения работает как обычно.
> Передумаете — включите на вкладке AI.

---

## Inglizcha (en)

**Title:** Trust AI — about your data

**Body:**

> To answer your question, Trust AI sends an **aggregated summary** of your finances (monthly
> income/expense totals, categories, debt amounts) and the text of your message to the AI service
> of **Anthropic**.
> Your counterparties' **real names are not sent** — they are replaced on our server with
> pseudonyms like `HAMKOR_1` and restored on your device after the reply arrives. Individual
> entries are never sent — only aggregate figures.
> The AI can be wrong and is **not a financial adviser** — use the button under each reply to
> report a bad answer.

**Buttons:**
- Primary: **I agree, let's start**
- Secondary: **Not now**
- Link: **Privacy Policy**

**On decline:**
> No problem — Trust AI stays off. The rest of the app works as usual.
> Change your mind? Turn it on from the AI tab.

---

## Boshqa tillar (es / fr / zh)

`l10n.dart` da 6 til bor. Hozircha **es/fr/zh uchun inglizcha matn** ishlatilsin (EN fallback) —
tarjima qilinmagan rozilik matni noto'g'ri ma'no berishi mumkin. Tarjima tayyor bo'lgach almashtiriladi.

---

## Dev eslatmasi (kim nima qiladi)

- **MOBILE:** `l10n.dart` ga kalitlar (`aiConsentTitle`, `aiConsentBody`, `aiConsentOk`,
  `aiConsentNo`, `aiConsentDeclined`) + `ai_chat.dart` da ekran. Rozilik `shared_preferences`
  YOKI serverda (`profiles.ai_consent_at`) saqlansin — **server afzal**: qurilma almashsa
  rozilik saqlanadi va audit uchun sana qoladi.
- **BACKEND:** rozilik sanasi maydoni + (tavsiya) `POST /api/ai/chat` da rozilik yo'q bo'lsa 403.
  Bu qatlam ishonchli — faqat mobil tekshiruvga tayanmaslik kerak.
- **Yozma dalil:** Play review'da so'ralsa, rozilik ekrani skrinshoti `docs/store-screenshots/` ga.
