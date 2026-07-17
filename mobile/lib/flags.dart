// Mahsulot bayroqlari (feature flags) — bitta joyda, ekranlar shu yerdan o'qiydi.
//
// kChatEnabled — 1:1 chat UI (product qarori, 2026-07-16: keyingi relizgacha YASHIRIN).
// Backend (src/routes/messages.js) JONLI qoladi — faqat UI ko'rinmaydi.
//
// false bo'lganda:
//   - screens/home.dart: hamkor qatorlaridagi o'qilmagan-xabar badge ko'rsatilmaydi;
//   - screens/notifs.dart: 'msg' turdagi bildirishnoma neytral "info" sifatida chiqadi
//     (store.dart openFromNotif 'msg' uchun faqat o'qilgan deb belgilaydi — navigatsiya yo'q).
//
// Chatni QAYTARISH uchun: shu bayroqni true qiling va docs/team-reports/
// 2026-07-16-partners.md "Follow-up phase" bo'limidagi P1/P2 store.dart patchlarini
// teskari qaytaring (msg bildirishnomasi yana hamkor sahifasiga olib boradigan bo'ladi).
const bool kChatEnabled = false;

// kCirclesEnabled — Circles (guruhli navbatli jamg'arma) menyusi.
// Mahsulot qarori (2026-07-17): auditoriya tor — Circles tabi o'rniga "Trust AI"
// keladi. Kod O'CHIRILMADI: ekranlar, store, API va backend joyida qoladi.
//
// false bo'lganda:
//   - screens/tab_bar.dart: pastki navigatsiyada Circles tugmasi ko'rinmaydi;
//   - main.dart: 'circles' tab ekrani chizilmaydi (unga o'tish yo'li ham yo'q).
//   Circle overlaylar (detail/join — bildirishnomadan ochiladi) ATAYLAB gate
//   qilinmagan: eski taklif bildirishnomasi bosilsa oqim buzilmasin.
//
// Circles'ni QAYTARISH: shu bayroqni true qiling — boshqa hech narsa kerak emas
// (kAiEnabled bilan birga true bo'lsa, pastki panelda 5 tugma bo'ladi).
const bool kCirclesEnabled = false;

// kAiEnabled — "Trust AI" moliyaviy hamroh chati (docs/ai-character.md).
// false bo'lganda: tabda ko'rinmaydi, ekran chizilmaydi (backend tegilmaydi).
const bool kAiEnabled = true;
