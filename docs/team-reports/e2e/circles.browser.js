// ============================================================================
// Trust CIRCLES — LIVE E2E skript (brauzer konsoli uchun)
// ----------------------------------------------------------------------------
// QANDAY ISHGA TUSHIRISH:
//   1. Brauzerda https://trust-backend-ft1s.onrender.com sahifasini oching
//      (relative fetch'lar shu originga ketadi).
//   2. Ikki TEST foydalanuvchi JWT tokenini oling (mobil app login yoki
//      POST /api/auth/send-otp + verify-otp orqali) va quyiga qo'ying.
//   3. Butun faylni konsolga paste qiling. Natija: ketma-ket PASS/FAIL + jadval.
//
// TEST MA'LUMOTLARI: barcha doiralar "TEST E2E ..." nomi bilan yaratiladi.
// Skript oxirida o'zi tozalaydi; faqat A doirasi ATAYIN soft-closed qoladi
// (dalil saqlanishini ko'rsatish uchun) — uni SQL bilan tozalang (hisobotda).
// ============================================================================
const TOKEN = '<<PASTE_JWT>>'; // USER 1 — doira egasi (owner; trial/premium bo'lsin!)
const TOKEN2 = '<<PASTE_JWT_USER2>>'; // USER 2 — taklif qilinadigan a'zo (boshqa telefon; trial/premium!)
// USER 3 — obunasi TUGAGAN foydalanuvchi (profiles.created_at > 7 kun oldin,
// premium_until = null). 12-bo'lim (402 SUB_EXPIRED) uchun; kiritilmasa SKIP bo'ladi.
const TOKEN3 = '<<PASTE_JWT_EXPIRED>>';

(async () => {
  const results = [];
  const api = async (token, method, path, body) => {
    const res = await fetch(path, {
      method,
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    let data = null;
    try { data = await res.json(); } catch (_) { /* bo'sh javob */ }
    return { status: res.status, ok: res.status < 400 && data?.success !== false, body: data };
  };
  const expect = (cond, msg) => { if (!cond) throw new Error(msg); };
  const step = async (name, fn) => {
    try {
      const info = await fn();
      results.push({ status: 'PASS', step: name, info: info || '' });
      console.log('%cPASS%c ' + name, 'color:#2F7A54;font-weight:bold', '', info || '');
    } catch (e) {
      results.push({ status: 'FAIL', step: name, info: e.message });
      console.log('%cFAIL%c ' + name, 'color:#A94438;font-weight:bold', '', e.message);
    }
  };
  const meOf = (c) => c.members.find((m) => m.is_you);

  let me1, me2;              // profillar
  let A, B, C, D;            // TEST doiralar (id + oxirgi holat)
  let aToken, cToken;        // A/C doira join_token'lari (faqat EGASI payload'ida bor —
                             // A/C keyin USER2 javobi bilan qayta yozilganda yo'qoladi)

  // ---------- 0. Sog'liq va tokenlar ----------
  await step('0.1 GET /health', async () => {
    const r = await fetch('/health').then((x) => x.json());
    expect(r.ok === true, 'health ok emas');
    return `service=${r.service} v${r.version}`;
  });
  await step('0.2 USER1 profil (/api/profile/me)', async () => {
    const r = await api(TOKEN, 'GET', '/api/profile/me');
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    me1 = r.body.data;
    return `id=${(me1.id || '').slice(0, 8)}… phone=${me1.phone}`;
  });
  await step('0.3 USER2 profil (/api/profile/me)', async () => {
    const r = await api(TOKEN2, 'GET', '/api/profile/me');
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    me2 = r.body.data;
    expect(me2.id !== me1.id, 'TOKEN2 boshqa foydalanuvchi bo\'lishi shart');
    return `id=${(me2.id || '').slice(0, 8)}… phone=${me2.phone}`;
  });

  // ---------- 1. Yaratish ----------
  await step('1.1 USER1 doira A yaratadi (You + USER2 telefon + nomli a\'zo)', async () => {
    const r = await api(TOKEN, 'POST', '/api/circles', {
      name: 'TEST E2E A', amount: 5, currency: 'USD', frequency: 'monthly', payout_order: 'inTurn',
      members: [
        { name: 'You', payout_position: 1, is_you: true },
        { name: 'TEST User2', phone: me2.phone, payout_position: 2 },
        { name: 'TEST Ghost', payout_position: 3 },
      ],
      due_dates: ['Aug 20', 'Sep 20', 'Oct 20'],
    });
    expect(r.status === 201 && r.ok, `status ${r.status}: ${r.body?.error}`);
    A = r.body.data;
    expect(A.status === 'active' && A.current_round === 1, 'active/round1 emas');
    expect(A.members.length === 3, `a'zolar ${A.members.length} != 3`);
    expect(!!A.join_token, 'egasiga join_token qaytishi kerak');
    aToken = A.join_token; // 11.6 uchun (A oradagi qadamlarda USER2 javobi bilan qayta yoziladi)
    expect(A.is_owner === true && A.my_status === 'active', 'owner/my_status xato');
    expect(A.rounds.length === 3 && A.rounds[0].status === 'current', 'roundlar xato');
    return `id=${A.id.slice(0, 8)}…`;
  });
  await step('1.2 Dublikat telefon bilan yaratish RAD etiladi', async () => {
    const r = await api(TOKEN, 'POST', '/api/circles', {
      name: 'TEST E2E DUP', amount: 5, currency: 'USD',
      members: [
        { name: 'You', payout_position: 1, is_you: true },
        { name: 'X', phone: me2.phone, payout_position: 2 },
        { name: 'Y', phone: me2.phone, payout_position: 3 },
      ],
    });
    expect(r.status === 400, `400 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });

  // ---------- 2. Ko'rish huquqlari ----------
  await step('2.1 USER2 ro\'yxatida A "invited" bo\'lib ko\'rinadi', async () => {
    const r = await api(TOKEN2, 'GET', '/api/circles');
    expect(r.ok, `status ${r.status}`);
    const a = r.body.data.find((c) => c.id === A.id);
    expect(!!a, 'A ro\'yxatda yo\'q');
    expect(a.my_status === 'invited', `my_status=${a.my_status}`);
    expect(a.join_token === null, 'join_token faqat egasiga ko\'rinishi kerak');
    expect(meOf(a) && meOf(a).name === 'TEST User2', 'is_you a\'zo topilmadi');
    return 'invited + token yashirin';
  });
  await step('2.2 SECURITY: a\'zo bo\'lmagan doira detali 403', async () => {
    const rb = await api(TOKEN, 'POST', '/api/circles', {
      name: 'TEST E2E B', amount: 7, currency: 'USD',
      members: [{ name: 'You', payout_position: 1, is_you: true }, { name: 'TEST Ghost', payout_position: 2 }],
    });
    expect(rb.status === 201, 'B yaratilmadi');
    B = rb.body.data;
    const r = await api(TOKEN2, 'GET', `/api/circles/${B.id}`);
    expect(r.status === 403, `403 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('2.3 SECURITY: a\'zo bo\'lmagan doiraga pay 403', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${B.id}/pay`);
    expect(r.status === 403, `403 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('2.4 SECURITY: invited (hali qo\'shilmagan) a\'zo pay qila olmaydi', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/pay`);
    expect(r.status === 403, `403 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });

  // ---------- 3. Qo'shilish (accept) ----------
  await step('3.1 USER2 taklifni qabul qiladi (accept)', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/accept`);
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    A = r.body.data;
    expect(A.my_status === 'active', 'accept dan keyin active emas');
    return 'my_status=active';
  });
  await step('3.2 (soft) USER2 ga circle_invite bildirishnomasi kelgan', async () => {
    const r = await api(TOKEN2, 'GET', '/api/notifications');
    expect(r.ok, `status ${r.status}`);
    const n = (r.body.data || []).find((x) => x.type === 'circle_invite' && x.circle_id === A.id);
    if (!n) return 'WARN: topilmadi (notif_enabled o\'chiq bo\'lishi mumkin)';
    return 'bor';
  });

  // ---------- 4. To'lov qoidalari ----------
  await step('4.1 Oluvchi (USER1, round1) o\'ziga to\'lay olmaydi', async () => {
    const r = await api(TOKEN, 'POST', `/api/circles/${A.id}/pay`);
    expect(r.status === 400, `400 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('4.2 USER2 to\'laydi (pay)', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/pay`);
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    A = r.body.data;
    const round1 = A.rounds.find((x) => x.idx === 1);
    const meM = meOf(A);
    expect(round1.paid_ids.includes(meM.id), 'paid_ids da USER2 yo\'q');
    return `paid_ids=${round1.paid_ids.length}`;
  });
  await step('4.3 Qayta pay — idempotent (double-pay yo\'q)', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/pay`);
    expect(r.ok, `status ${r.status}`);
    const round1 = r.body.data.rounds.find((x) => x.idx === 1);
    expect(round1.paid_ids.length === 1, `paid_ids ${round1.paid_ids.length} != 1`);
    return 'paid_ids hali ham 1';
  });

  // ---------- 5. Tasdiqlash (confirm) qoidalari ----------
  await step('5.1 SECURITY: oluvchi bo\'lmagan USER2 confirm qila olmaydi', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/confirm`);
    expect(r.status === 403, `403 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('5.2 USER1 (round1 oluvchisi) confirm — round yopiladi, navbat siljiydi', async () => {
    const r = await api(TOKEN, 'POST', `/api/circles/${A.id}/confirm`);
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    A = r.body.data;
    const r1 = A.rounds.find((x) => x.idx === 1);
    const r2 = A.rounds.find((x) => x.idx === 2);
    expect(r1.status === 'done' && r1.receipt_confirmed === true, 'round1 yopilmadi');
    expect(A.current_round === 2 && r2.status === 'current', 'round2 current emas');
    const u2m = A.members.find((m) => m.name === 'TEST User2');
    expect(r2.recipient_id === u2m.id, 'round2 oluvchisi USER2 emas');
    return 'round 1 done -> round 2 current (USER2 navbati)';
  });
  await step('5.3 USER1 endi confirm qila olmaydi (oluvchi USER2)', async () => {
    const r = await api(TOKEN, 'POST', `/api/circles/${A.id}/confirm`);
    expect(r.status === 403 || r.status === 400, `403/400 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });

  // ---------- 6. Eslatma (remind) ----------
  await step('6.1 USER2 (joriy oluvchi) remind — USER1 ga eslatma ketadi', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/remind`);
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    expect(r.body.data.reminded === 1, `reminded=${r.body.data.reminded} != 1`);
    return 'reminded=1 (USER1)';
  });

  // ---------- 7. Taklif (invite) qoidalari ----------
  await step('7.1 SECURITY: USER2 (egasi emas) invite qila olmaydi', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/invite`, { members: [{ name: 'TEST Z' }] });
    expect(r.status === 403, `403 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('7.2 Doirada bor raqamni qayta taklif qilish RAD etiladi', async () => {
    const r = await api(TOKEN, 'POST', `/api/circles/${A.id}/invite`, { members: [{ name: 'TEST Dup', phone: me2.phone }] });
    expect(r.status === 400, `400 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('7.3 USER1 yangi nomli a\'zo qo\'shadi — pozitsiya/round oxiriga', async () => {
    const r = await api(TOKEN, 'POST', `/api/circles/${A.id}/invite`, { members: [{ name: 'TEST Late' }] });
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    A = r.body.data;
    expect(A.members.length === 4 && A.rounds.length === 4, `4/4 kutildi: ${A.members.length}/${A.rounds.length}`);
    return 'members=4 rounds=4';
  });

  // ---------- 8. Nom tahriri ----------
  await step('8.1 SECURITY: USER2 rename qila olmaydi (PATCH 403)', async () => {
    const r = await api(TOKEN2, 'PATCH', `/api/circles/${A.id}`, { name: 'HACKED' });
    expect(r.status === 403, `403 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('8.2 USER1 rename qiladi', async () => {
    const r = await api(TOKEN, 'PATCH', `/api/circles/${A.id}`, { name: 'TEST E2E A (renamed)' });
    expect(r.ok && r.body.data.name === 'TEST E2E A (renamed)', 'nom yangilanmadi');
    return r.body.data.name;
  });

  // ---------- 9. Havola (join_token) orqali qo'shilish ----------
  await step('9.1 USER1 doira C yaratadi, USER2 token PREVIEW ko\'radi', async () => {
    const rc = await api(TOKEN, 'POST', '/api/circles', {
      name: 'TEST E2E C', amount: 3, currency: 'USD',
      members: [{ name: 'You', payout_position: 1, is_you: true }, { name: 'TEST Ghost', payout_position: 2 }],
    });
    expect(rc.status === 201, 'C yaratilmadi');
    C = rc.body.data;
    expect(!!C.join_token, 'C join_token yo\'q');
    cToken = C.join_token; // keyingi qadamlar uchun saqlaymiz (C qayta yoziladi)
    const r = await api(TOKEN2, 'GET', `/api/circles/join/${cToken}`);
    expect(r.ok, `preview status ${r.status}: ${r.body?.error}`);
    expect(r.body.data.members_count === 2 && r.body.data.already_member === false, 'preview xato');
    return `preview: ${r.body.data.name}, next_position=${r.body.data.next_position}`;
  });
  await step('9.2 USER2 token bilan QO\'SHILADI (oxirgi pozitsiya + yangi round)', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/join/${cToken}`);
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    C = r.body.data;
    expect(C.my_status === 'active', 'join dan keyin active emas');
    expect(C.members.length === 3 && C.rounds.length === 3, `3/3 kutildi: ${C.members.length}/${C.rounds.length}`);
    expect(meOf(C).payout_position === 3, `pozitsiya ${meOf(C).payout_position} != 3`);
    return 'joined @position 3';
  });
  await step('9.3 Token bilan qayta join — idempotent', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/join/${cToken}`);
    expect(r.ok && r.body.data.members.length === 3, 'idempotent emas');
    return 'members hali ham 3';
  });
  await step('9.4 Noto\'g\'ri token PREVIEW 404 (mobil: "kod topilmadi")', async () => {
    const r = await api(TOKEN2, 'GET', '/api/circles/join/deadbeefdeadbeefff');
    expect(r.status === 404, `404 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('9.5 Noto\'g\'ri token bilan JOIN (POST) ham 404', async () => {
    const r = await api(TOKEN2, 'POST', '/api/circles/join/deadbeefdeadbeefff');
    expect(r.status === 404, `404 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });

  // ---------- 10. Rad etish (decline) — siqish (deadlock himoyasi) ----------
  await step('10.1 Decline: a\'zo + round olib tashlanadi, pozitsiyalar siqiladi', async () => {
    const rd = await api(TOKEN, 'POST', '/api/circles', {
      name: 'TEST E2E D', amount: 2, currency: 'USD',
      members: [
        { name: 'You', payout_position: 1, is_you: true },
        { name: 'TEST User2', phone: me2.phone, payout_position: 2 },
        { name: 'TEST Ghost', payout_position: 3 },
      ],
    });
    expect(rd.status === 201, 'D yaratilmadi');
    D = rd.body.data;
    const r = await api(TOKEN2, 'POST', `/api/circles/${D.id}/decline`);
    expect(r.ok, `decline status ${r.status}`);
    const g = await api(TOKEN, 'GET', `/api/circles/${D.id}`);
    expect(g.ok, 'D o\'qilmadi');
    D = g.body.data;
    expect(D.members.length === 2, `a'zolar ${D.members.length} != 2 (arvoh qolgan!)`);
    expect(D.rounds.length === 2, `roundlar ${D.rounds.length} != 2`);
    expect(D.rounds.map((x) => x.idx).join(',') === '1,2', 'idx siqilmagan');
    expect(D.members.map((x) => x.payout_position).join(',') === '1,2', 'pozitsiya siqilmagan');
    return 'members=2 rounds=2 (siqildi)';
  });
  await step('10.2 Decline dan keyin USER2 ro\'yxatida D YO\'Q (sizish yo\'q)', async () => {
    const r = await api(TOKEN2, 'GET', '/api/circles');
    expect(r.ok, `status ${r.status}`);
    expect(!r.body.data.find((c) => c.id === D.id), 'D hali ham ro\'yxatda');
    return 'yo\'q';
  });

  // ---------- 11. Yopish semantikasi ----------
  await step('11.1 Dalilsiz doira (D) hard-delete bo\'ladi', async () => {
    const r = await api(TOKEN, 'DELETE', `/api/circles/${D.id}`);
    expect(r.ok && r.body.data.ok === true, `status ${r.status}`);
    const g = await api(TOKEN, 'GET', `/api/circles/${D.id}`);
    expect(g.status === 404, '404 kutildi — o\'chirilmagan');
    return 'hard delete + 404';
  });
  await step('11.2 SECURITY: USER2 (egasi emas) A ni yopa olmaydi', async () => {
    const r = await api(TOKEN2, 'DELETE', `/api/circles/${A.id}`);
    expect(r.status === 403, `403 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('11.3 Dalilli doira (A, round1 done) SOFT-close bo\'ladi', async () => {
    const r = await api(TOKEN, 'DELETE', `/api/circles/${A.id}`);
    expect(r.ok, `status ${r.status}: ${r.body?.error}`);
    expect(r.body.data.status === 'closed', `status=${r.body.data.status} != closed`);
    const g = await api(TOKEN, 'GET', `/api/circles/${A.id}`);
    expect(g.ok && g.body.data.status === 'closed', 'closed saqlanmadi');
    return 'soft-closed, yozuvlar joyida';
  });
  await step('11.4 Yopilgan doiraga pay 400', async () => {
    const r = await api(TOKEN2, 'POST', `/api/circles/${A.id}/pay`);
    expect(r.status === 400, `400 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('11.5 Yopilgan (dalilli) doirani qayta DELETE — RAD (dalil o\'chmaydi)', async () => {
    const r = await api(TOKEN, 'DELETE', `/api/circles/${A.id}`);
    expect(r.status === 400, `400 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });
  await step('11.6 Yopilgan doira kodi: PREVIEW status=closed, JOIN 400 (mobil: "yakunlangan")', async () => {
    expect(!!aToken, 'aToken yo\'q (1.1 dan saqlanishi kerak edi)');
    const g = await api(TOKEN2, 'GET', `/api/circles/join/${aToken}`);
    expect(g.ok && g.body.data.status === 'closed', `preview status=${g.body?.data?.status} != closed`);
    const r = await api(TOKEN2, 'POST', `/api/circles/join/${aToken}`);
    expect(r.status === 400, `400 kutildi, keldi ${r.status}`);
    return r.body?.error;
  });

  // ---------- 12. OBUNA (read-only enforcement): muddati tugagan foydalanuvchi ----------
  // Qoida: yangi qiymat YARATADIGAN endpointlar 402 SUB_EXPIRED (create/join/invite/pay);
  // GET'lar va javob endpointlari (accept/decline/confirm/remind) OCHIQ qoladi.
  const HAS3 = !TOKEN3.includes('<<');
  let me3;
  await step('12.1 EXPIRED profil + GET /api/circles OCHIQ (read-only)', async () => {
    if (!HAS3) return 'SKIP — TOKEN3 kiritilmagan';
    const p = await api(TOKEN3, 'GET', '/api/profile/me');
    expect(p.ok, `profil status ${p.status}: ${p.body?.error}`);
    me3 = p.body.data;
    expect(me3.id !== me1.id && me3.id !== me2.id, 'TOKEN3 alohida foydalanuvchi bo\'lsin');
    const r = await api(TOKEN3, 'GET', '/api/circles');
    expect(r.ok, `GET /api/circles status ${r.status} — o'qish bloklanmasligi kerak`);
    return `id=${(me3.id || '').slice(0, 8)}… (GET ochiq)`;
  });
  await step('12.2 EXPIRED doira yarata OLMAYDI — 402 SUB_EXPIRED', async () => {
    if (!HAS3) return 'SKIP — TOKEN3 kiritilmagan';
    const r = await api(TOKEN3, 'POST', '/api/circles', {
      name: 'TEST E2E EXPIRED', amount: 1, currency: 'USD',
      members: [{ name: 'You', payout_position: 1, is_you: true }, { name: 'X', payout_position: 2 }],
    });
    expect(r.status === 402, `402 kutildi, keldi ${r.status}`);
    expect(r.body?.code === 'SUB_EXPIRED', `code=${r.body?.code} != SUB_EXPIRED`);
    return r.body?.error;
  });
  await step('12.3 EXPIRED kod bilan qo\'shila OLMAYDI — 402 (mobil: subExpiredErr)', async () => {
    if (!HAS3) return 'SKIP — TOKEN3 kiritilmagan';
    const r = await api(TOKEN3, 'POST', `/api/circles/join/${cToken}`);
    expect(r.status === 402 && r.body?.code === 'SUB_EXPIRED', `402/SUB_EXPIRED kutildi, keldi ${r.status}/${r.body?.code}`);
    return r.body?.error;
  });
  await step('12.4 EXPIRED taklifga JAVOB bera oladi (accept ochiq — qarshi tomon qotmasin)', async () => {
    if (!HAS3) return 'SKIP — TOKEN3 kiritilmagan';
    const inv = await api(TOKEN, 'POST', `/api/circles/${C.id}/invite`, { members: [{ name: 'TEST Expired', phone: me3.phone }] });
    expect(inv.ok, `owner invite status ${inv.status}: ${inv.body?.error}`);
    const r = await api(TOKEN3, 'POST', `/api/circles/${C.id}/accept`);
    expect(r.ok, `accept status ${r.status}: ${r.body?.error} — accept 402 bo'lmasligi kerak!`);
    expect(r.body.data.my_status === 'active', 'accept dan keyin active emas');
    return 'accept OK (402 emas)';
  });
  await step('12.5 EXPIRED to\'lov boshlay OLMAYDI — pay 402', async () => {
    if (!HAS3) return 'SKIP — TOKEN3 kiritilmagan';
    const r = await api(TOKEN3, 'POST', `/api/circles/${C.id}/pay`);
    expect(r.status === 402 && r.body?.code === 'SUB_EXPIRED', `402/SUB_EXPIRED kutildi, keldi ${r.status}/${r.body?.code}`);
    return r.body?.error;
  });
  await step('12.6 EXPIRED doira detalini O\'QIY oladi (GET /:id ochiq)', async () => {
    if (!HAS3) return 'SKIP — TOKEN3 kiritilmagan';
    const r = await api(TOKEN3, 'GET', `/api/circles/${C.id}`);
    expect(r.ok, `status ${r.status} — a'zo uchun GET ochiq bo'lishi kerak`);
    return `members=${r.body.data.members.length}`;
  });

  // ---------- 13. Tozalash ----------
  await step('13.1 Tozalash: B va C o\'chiriladi (dalilsiz)', async () => {
    const r1 = await api(TOKEN, 'DELETE', `/api/circles/${B.id}`);
    const r2 = await api(TOKEN, 'DELETE', `/api/circles/${C.id}`);
    expect(r1.ok && r2.ok, `B=${r1.status} C=${r2.status}`);
    return 'B, C o\'chirildi. A (closed) — SQL bilan tozalang (hisobotga qarang)';
  });

  // ---------- Xulosa ----------
  const pass = results.filter((r) => r.status === 'PASS').length;
  console.log(`\n===== CIRCLES E2E: ${pass}/${results.length} PASS =====`);
  console.table(results);
})();
