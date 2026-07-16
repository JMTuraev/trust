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
