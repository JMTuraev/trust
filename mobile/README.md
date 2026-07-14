# Trust — Oldi-Berdi (mobil ilova)

React Native (Expo) ilovasi. O'zbek + rus tilli. `trust` backend'iga ulanadi.

## Ishga tushirish

```bash
cd mobile
npm install
npm start
```

Telefoningizga **Expo Go** ilovasini o'rnating (App Store / Play Market), so'ng terminaldagi QR kodni skanerlang.

## API manzilini sozlash

`app.json` -> `expo.extra.apiUrl` ni backend manziliga o'zgartiring:
- Lokal test (telefon + kompyuter bir WiFi'da): kompyuteringiz IP'si, masalan `http://192.168.1.100:3000`
- Deploy qilingandan keyin: haqiqiy URL, masalan `https://trust-backend.up.railway.app`

Yoki `EXPO_PUBLIC_API_URL` muhit o'zgaruvchisi orqali.

## Ekranlar
- Login — telefon + OTP (til tanlash)
- Qarzlar — ro'yxat, umumiy summa (menga qarzdor / men qarzdorman)
- Qarz qo'shish — men berdim / men oldim
- Qarz tafsiloti — tasdiqlash, qisman to'lov, bekor qilish
- Profil — ism, til, chiqish
