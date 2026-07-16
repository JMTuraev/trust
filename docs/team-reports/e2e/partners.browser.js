// ============================================================================
// TRUST — PARTNERS oqimi LIVE E2E (brauzer-konsol skripti)
// ============================================================================
// QANDAY ISHGA TUSHIRILADI:
//   1) Supabase SQL editor'da fixture'larni yarating
//      (SQL: docs/team-reports/2026-07-16-partners.md, "E2E fixtures" bo'limi).
//   2) Repo root'da uchta token imzolang:
//        node docs/team-reports/e2e/sign-test-jwt.mjs 11111111-1111-4111-8111-111111111101 998900000001
//        node docs/team-reports/e2e/sign-test-jwt.mjs 11111111-1111-4111-8111-111111111102 998900000002
//        node docs/team-reports/e2e/sign-test-jwt.mjs 11111111-1111-4111-8111-111111111103 998900000003
//      (C — obunasi TUGAGAN foydalanuvchi; fixture SQL'da created_at 30 kun orqaga suriladi,
//       qarang: hisobot "Follow-up phase" bo'limi. TOKEN_C bo'sh qolsa 20-23 qadamlar SKIP.)
//   3) Brauzerda https://trust-backend-ft1s.onrender.com/health sahifasini oching
//      (skript shu origin'dan nisbiy /api yo'llari bilan ishlaydi).
//   4) Quyidagi TOKEN_A/TOKEN_B ga tokenlarni qo'ying va butun faylni konsolga tashlang.
//   5) Yakunda Supabase'da cleanup SQL'ni bajaring (hisobotdagi "E2E cleanup").
//
// FAQAT TEST MA'LUMOTI ISHLATILADI: nomlar 'TEST-E2E ...', raqamlar +99890000000x.
// Skript ketma-ket ishlaydi, har qadam PASS/FAIL chiqaradi, yiqilgan qadam
// keyingilarini to'xtatmaydi (bog'liq qadamlar SKIP bo'ladi).
// ============================================================================

const TOKEN_A = '<<PASTE_JWT>>'; // seller — 11111111-...-101 (998900000001)
const TOKEN_B = '<<PASTE_JWT>>'; // client — 11111111-...-102 (998900000002)
const TOKEN_C = '<<PASTE_JWT>>'; // EXPIRED — 11111111-...-103 (998900000003), obuna muddati tugagan

(async () => {
  const results = [];
  const ctx = { partnerId: null, debtId: null, repayId: null, settleId: null, pid3: null, debt3: null };
  const today = new Date().toISOString().slice(0, 10);

  async function api(token, method, path, body) {
    const res = await fetch(path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    let json = null;
    try { json = await res.json(); } catch (_) { /* bo'sh javob */ }
    return { status: res.status, json };
  }
  const A = (m, p, b) => api(TOKEN_A, m, p, b);
  const B = (m, p, b) => api(TOKEN_B, m, p, b);
  const C = (m, p, b) => api(TOKEN_C, m, p, b);

  function log(ok, name, detail) {
    const line = `${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ' — ' + detail : ''}`;
    results.push({ ok, name, detail });
    console.log(`%c${line}`, `color:${ok ? 'green' : 'red'};font-weight:bold`);
  }

  async function step(name, fn) {
    try {
      const detail = await fn();
      log(true, name, typeof detail === 'string' ? detail : '');
    } catch (e) {
      log(false, name, e && e.message ? e.message : String(e));
    }
  }
  function expect(cond, msg, got) {
    if (!cond) throw new Error(`${msg}${got !== undefined ? ` (kelgan: ${JSON.stringify(got)})` : ''}`);
  }

  console.log('=== TRUST PARTNERS E2E boshlanmoqda ===', new Date().toISOString());
  if (TOKEN_A.includes('<<') || TOKEN_B.includes('<<')) {
    console.error('TOKEN_A / TOKEN_B to\'ldirilmagan — sign-test-jwt.mjs bilan imzolang.');
    return;
  }

  // ------------------------------------------------------------------ 0. health
  await step('0. GET /health', async () => {
    const r = await api(null, 'GET', '/health');
    expect(r.status === 200 && r.json && r.json.ok === true, 'health ok emas', r.json);
    return `service=${r.json.service} v=${r.json.version}`;
  });

  // ------------------------------------------------------------------ 1. auth
  await step('1. A: GET /api/partners (auth ishlaydi)', async () => {
    const r = await A('GET', '/api/partners');
    expect(r.status === 200 && r.json.success === true, `status=${r.status}`, r.json);
    return `hamkorlar: ${r.json.data.length} ta`;
  });

  await step('1b. Token yo\'q -> 401', async () => {
    const r = await api(null, 'GET', '/api/partners');
    expect(r.status === 401, `401 kutilgan, status=${r.status}`, r.json);
  });

  // ------------------------------------------------------------------ 2. hamkor yaratish
  await step('2. A: POST /api/partners (TEST hamkor, B raqami)', async () => {
    const r = await A('POST', '/api/partners', {
      name: 'TEST-E2E Hamkor',
      counterparty_phone: '998900000002',
    });
    if (r.status === 409) {
      throw new Error('409 — oldingi test qoldig\'i bor: avval cleanup SQL\'ni bajaring');
    }
    expect(r.status === 201 && r.json.success, `status=${r.status}`, r.json);
    expect(r.json.data.link_status === 'pending', 'link_status pending emas', r.json.data.link_status);
    expect(!!r.json.data.counterparty_id, 'counterparty_id bo\'sh — B fixture yaratilmaganmi?');
    ctx.partnerId = r.json.data.id;
    return `partner_id=${ctx.partnerId}`;
  });

  await step('2b. A: o\'z raqamini qo\'shish -> 400', async () => {
    const r = await A('POST', '/api/partners', { name: 'TEST-E2E Self', counterparty_phone: '998900000001' });
    expect(r.status === 400, `400 kutilgan, status=${r.status}`, r.json);
  });

  // ------------------------------------------------------------------ 3. oneSided qarz (link hali pending)
  await step('3. A: POST /api/debts/:pid — qarz 150 000 (oneSided, darhol active)', async () => {
    expect(ctx.partnerId, 'partnerId yo\'q (2-qadam yiqilgan)');
    const r = await A('POST', `/api/debts/${ctx.partnerId}`, {
      direction: 'toMe', amount: 150000, currency: 'UZS', acted_at: today, note: 'TEST-E2E qarz',
    });
    expect(r.status === 201 && r.json.success, `status=${r.status}`, r.json);
    expect(r.json.data.status === 'active', 'oneSided qarz darhol active emas', r.json.data.status);
    expect(r.json.data.prov === 'oneSided', 'prov oneSided emas', r.json.data.prov);
    ctx.debtId = r.json.data.id;
    return `debt_id=${ctx.debtId}`;
  });

  await step('3b. Validatsiya: amount<=0 -> 400, currency XYZ -> 400, kelajak acted_at -> 400', async () => {
    const r1 = await A('POST', `/api/debts/${ctx.partnerId}`, { direction: 'toMe', amount: -5 });
    expect(r1.status === 400, `amount -5: 400 kutilgan, status=${r1.status}`);
    const r2 = await A('POST', `/api/debts/${ctx.partnerId}`, { direction: 'toMe', amount: 100, currency: 'XYZ' });
    expect(r2.status === 400, `currency XYZ: 400 kutilgan, status=${r2.status}`);
    const future = new Date(Date.now() + 5 * 86400000).toISOString().slice(0, 10);
    const r3 = await A('POST', `/api/debts/${ctx.partnerId}`, { direction: 'toMe', amount: 100, acted_at: future });
    expect(r3.status === 400, `kelajak sana: 400 kutilgan, status=${r3.status}`);
  });

  // ------------------------------------------------------------------ 4. mijoz preview (links)
  await step('4. B: GET /api/links — preview ledger qarzini ko\'radi (ops_count>=1, totals.UZS=-150000)', async () => {
    const r = await B('GET', '/api/links');
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    const link = (r.json.data || []).find((l) => l.id === ctx.partnerId);
    expect(link, 'B ro\'yxatida TEST link topilmadi');
    expect(link.status === 'pending', 'status pending emas', link.status);
    expect(link.ops_count >= 1, 'ops_count 0 — ledger qarzi previewda sanalmadi', link.ops_count);
    expect(link.totals && link.totals.UZS === -150000, 'totals.UZS != -150000', link.totals);
    return `ops_count=${link.ops_count}, totals=${JSON.stringify(link.totals)}`;
  });

  // ------------------------------------------------------------------ 5. qabul + review navbati
  await step('5. B: POST /api/links/:id/accept -> qarz under_review bo\'ladi', async () => {
    const r = await B('POST', `/api/links/${ctx.partnerId}/accept`);
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    const d = await B('GET', `/api/debts/${ctx.partnerId}`);
    expect(d.status === 200 && d.json.success, `debts status=${d.status}`, d.json);
    const row = (d.json.data || []).find((x) => x.id === ctx.debtId);
    expect(row, 'B qarz yozuvini ko\'rmayapti');
    expect(row.under_review === true, 'under_review true emas', row.under_review);
  });

  await step('6. B: review-confirm -> prov twoSided', async () => {
    const r = await B('POST', `/api/debts/${ctx.partnerId}/review-confirm`, { debt_id: ctx.debtId });
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    expect(r.json.data.prov === 'twoSided', 'prov twoSided emas', r.json.data.prov);
    expect(r.json.data.under_review === false, 'under_review false emas');
  });

  // ------------------------------------------------------------------ 7. qarama-qarshi yo'nalish taqiqi
  await step('7. B: qarama-qarshi yo\'nalishda yangi qarz -> 400', async () => {
    // B 'toMe' (B nuqtai nazarida) = owner(A) nuqtai nazarida 'fromMe' — faol toMe(A) ga qarshi
    const r = await B('POST', `/api/debts/${ctx.partnerId}`, { direction: 'toMe', amount: 1000 });
    expect(r.status === 400, `400 kutilgan, status=${r.status}`, r.json);
  });

  // ------------------------------------------------------------------ 8-9. repay + ikki tomonlama tasdiq
  await step('8. B: repay 50 000 -> pending', async () => {
    const r = await B('POST', `/api/debts/${ctx.partnerId}/repay`, {
      ref_id: ctx.debtId, amount: 50000, note: 'TEST-E2E qaytarish',
    });
    expect(r.status === 201 && r.json.success, `status=${r.status}`, r.json);
    expect(r.json.data.status === 'pending', 'repay pending emas', r.json.data.status);
    ctx.repayId = r.json.data.id;
  });

  await step('8b. Band (locked) qarzga ikkinchi amal -> 409', async () => {
    const r = await B('POST', `/api/debts/${ctx.partnerId}/repay`, { ref_id: ctx.debtId, amount: 10 });
    expect(r.status === 409, `409 kutilgan, status=${r.status}`, r.json);
  });

  await step('8c. B o\'z repay\'ini o\'zi tasdiqlay olmaydi -> 403', async () => {
    const r = await B('POST', `/api/debts/${ctx.repayId}/confirm-op`);
    expect(r.status === 403, `403 kutilgan, status=${r.status}`, r.json);
  });

  await step('9. A: confirm-op -> qarzga qo\'llanadi (paid=50000)', async () => {
    const r = await A('POST', `/api/debts/${ctx.repayId}/confirm-op`);
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    const d = await A('GET', `/api/debts/${ctx.partnerId}`);
    const row = (d.json.data || []).find((x) => x.id === ctx.debtId);
    expect(Number(row.paid) === 50000, 'paid != 50000', row.paid);
    expect(row.status === 'active', 'qarz active bo\'lib qolishi kerak', row.status);
    expect(Number(row.remaining) === 100000, 'remaining != 100000', row.remaining);
  });

  await step('9b. Takroriy confirm-op (idempotentlik) -> 409', async () => {
    const r = await A('POST', `/api/debts/${ctx.repayId}/confirm-op`);
    expect(r.status === 400 || r.status === 409, `409/400 kutilgan, status=${r.status}`, r.json);
  });

  // ------------------------------------------------------------------ 10-11. tahrir (pending_edit)
  await step('10. A: PATCH qarz amount 200 000 -> pending_edit (qarz eski holida)', async () => {
    const r = await A('PATCH', `/api/debts/${ctx.debtId}`, { amount: 200000 });
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    expect(r.json.data.pending_edit, 'pending_edit yo\'q', r.json.data.pending_edit);
    expect(Number(r.json.data.amount) === 150000, 'amount hali eski (150000) bo\'lishi kerak', r.json.data.amount);
  });

  await step('11. B: edit-confirm -> amount=200000, paid saqlanadi', async () => {
    const r = await B('POST', `/api/debts/${ctx.debtId}/edit-confirm`);
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    expect(Number(r.json.data.amount) === 200000, 'amount != 200000', r.json.data.amount);
    expect(Number(r.json.data.paid) === 50000, 'paid != 50000', r.json.data.paid);
    expect(!r.json.data.pending_edit, 'pending_edit tozalanmadi');
  });

  // ------------------------------------------------------------------ 12. settle -> yopilish
  await step('12. A: settle 150 000 (returned) -> pending; B tasdiqlaydi -> qarz closed', async () => {
    const r = await A('POST', `/api/debts/${ctx.partnerId}/settle`, {
      ref_id: ctx.debtId, amount: 150000, reason: 'returned', note: 'TEST-E2E yopish',
    });
    expect(r.status === 201 && r.json.success, `settle status=${r.status}`, r.json);
    ctx.settleId = r.json.data.id;
    const c = await B('POST', `/api/debts/${ctx.settleId}/confirm-op`);
    expect(c.status === 200 && c.json.success, `confirm status=${c.status}`, c.json);
    const d = await A('GET', `/api/debts/${ctx.partnerId}`);
    const row = (d.json.data || []).find((x) => x.id === ctx.debtId);
    expect(row.status === 'closed', 'qarz closed emas', row.status);
    expect(Number(row.paid) === 200000, 'paid != 200000', row.paid);
    expect(row.reason === 'returned', 'reason returned emas', row.reason);
  });

  await step('12b. Yopilgan qarzga repay -> 400', async () => {
    const r = await B('POST', `/api/debts/${ctx.partnerId}/repay`, { ref_id: ctx.debtId, amount: 10 });
    expect(r.status === 400, `400 kutilgan, status=${r.status}`, r.json);
  });

  // ------------------------------------------------------------------ 13. chat (messages)
  await step('13. A: matn xabar -> B ko\'radi, unread badge, read tozalaydi', async () => {
    const s = await A('POST', `/api/messages/${ctx.partnerId}`, { kind: 'text', body: 'TEST-E2E xabar' });
    expect(s.status === 201 && s.json.success, `send status=${s.status}`, s.json);
    const list = await B('GET', `/api/messages/${ctx.partnerId}`);
    expect(list.status === 200 && (list.json.data || []).some((m) => m.body === 'TEST-E2E xabar'),
      'B xabarni ko\'rmadi', list.json);
    const un = await B('GET', '/api/messages/unread/counts');
    expect(un.json.data && Number(un.json.data[ctx.partnerId]) >= 1, 'unread hisoblagich 0', un.json.data);
    const rd = await B('POST', `/api/messages/${ctx.partnerId}/read`);
    expect(rd.status === 200, `read status=${rd.status}`);
    const un2 = await B('GET', '/api/messages/unread/counts');
    expect(!un2.json.data[ctx.partnerId], 'read\'dan keyin unread qolib ketdi', un2.json.data);
  });

  await step('13b. Bo\'sh xabar -> 400; 2000+ belgi -> 400', async () => {
    const r1 = await A('POST', `/api/messages/${ctx.partnerId}`, { kind: 'text', body: '   ' });
    expect(r1.status === 400, `bo'sh: 400 kutilgan, status=${r1.status}`);
    const r2 = await A('POST', `/api/messages/${ctx.partnerId}`, { kind: 'text', body: 'x'.repeat(2001) });
    expect(r2.status === 400, `uzun: 400 kutilgan, status=${r2.status}`);
  });

  // ------------------------------------------------------------------ 14. notifications
  await step('14. B: bildirishnomalar kelgan (link_new/review_req/edit_req/settle_new/msg)', async () => {
    const r = await B('GET', '/api/notifications');
    expect(r.status === 200 && r.json.success, `status=${r.status}`);
    const mine = (r.json.data || []).filter((n) => n.link_id === ctx.partnerId);
    expect(mine.length >= 2, 'TEST linkka oid bildirishnoma kam', mine.length);
    const types = [...new Set(mine.map((n) => n.type))];
    return `turlar: ${types.join(', ')}`;
  });

  await step('14b. B: read-all -> hammasi o\'qilgan', async () => {
    const r = await B('POST', '/api/notifications/read-all');
    expect(r.status === 200 && r.json.success, `status=${r.status}`);
    const l = await B('GET', '/api/notifications');
    expect((l.json.data || []).every((n) => n.read === true), 'o\'qilmagan qoldi');
  });

  // ------------------------------------------------------------------ 15. remind
  await step('15. A: remind (balans 0 — baribir 200/429)', async () => {
    const r = await A('POST', `/api/partners/${ctx.partnerId}/remind`);
    expect(r.status === 200 || r.status === 429, `200/429 kutilgan, status=${r.status}`, r.json);
    return `status=${r.status}`;
  });

  // ------------------------------------------------------------------ 16-17. disconnect + mask + restore
  await step('16. B: disconnect -> A hali "pending" ko\'radi (rad signali kechiktirilgan)', async () => {
    const r = await B('POST', `/api/links/${ctx.partnerId}/disconnect`);
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    const pa = await A('GET', '/api/partners');
    const row = (pa.json.data || []).find((p) => p.id === ctx.partnerId);
    expect(row, 'A hamkorini topmadi');
    expect(row.link_status === 'pending', `mask ishlamadi: A '${row.link_status}' ko'ryapti (signal yuborilmaguncha 'pending' bo'lishi kerak)`);
  });

  await step('17. B: restore -> accepted; takroriy restore -> 400', async () => {
    const r = await B('POST', `/api/links/${ctx.partnerId}/restore`);
    expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
    expect(r.json.data.link_status === 'accepted', 'accepted emas', r.json.data.link_status);
    const again = await B('POST', `/api/links/${ctx.partnerId}/restore`);
    expect(again.status === 400, `takroriy restore: 400 kutilgan, status=${again.status}`);
  });

  // ------------------------------------------------------------------ 18. alias + partner PATCH
  await step('18. B: PATCH alias; A: PATCH name/archived', async () => {
    const al = await B('PATCH', `/api/links/${ctx.partnerId}`, { alias: 'TEST-E2E Alias' });
    expect(al.status === 200 && al.json.data.client_alias === 'TEST-E2E Alias', 'alias saqlanmadi', al.json);
    const nm = await A('PATCH', `/api/partners/${ctx.partnerId}`, { name: 'TEST-E2E Hamkor 2' });
    expect(nm.status === 200 && nm.json.data.name === 'TEST-E2E Hamkor 2', 'name saqlanmadi', nm.json);
    const ar = await A('PATCH', `/api/partners/${ctx.partnerId}`, { archived: true });
    expect(ar.status === 200 && ar.json.data.archived === true, 'archived saqlanmadi', ar.json);
    const un = await A('PATCH', `/api/partners/${ctx.partnerId}`, { archived: false });
    expect(un.status === 200 && un.json.data.archived === false, 'arxivdan qaytmadi', un.json);
  });

  // ------------------------------------------------------------------ 19. huquq chegaralari
  await step('19. B boshqa birovning hamkorini PATCH qila olmaydi -> 404', async () => {
    const r = await B('PATCH', `/api/partners/${ctx.partnerId}`, { name: 'HACK' });
    expect(r.status === 404, `404 kutilgan, status=${r.status}`, r.json);
  });

  // ------------------------------------------------------------------ 20-23. OBUNA read-only (402)
  // C = obunasi TUGAGAN foydalanuvchi (fixture: profiles.created_at 30 kun orqaga surilgan,
  // premium_until yo'q -> computeSubscription 'expired'). Qoida (PO, 2026-07-16):
  // YOZISH (yangi hamkor / yangi qarz / repay / xabar) -> 402 SUB_EXPIRED;
  // JAVOB amallari (accept/confirm/reject) va GET'lar OCHIQ — muddati tugagan
  // foydalanuvchining qarshi tomoni hech qachon qulflanib qolmasin.
  if (TOKEN_C.includes('<<')) {
    console.warn('20-23-qadamlar SKIP: TOKEN_C to\'ldirilmagan (obuna 402 testlari o\'tkazilmadi)');
  } else {
    await step('20. C(expired): POST /api/partners -> 402 SUB_EXPIRED', async () => {
      const r = await C('POST', '/api/partners', { name: 'TEST-E2E C hamkor', counterparty_phone: '998900000002' });
      expect(r.status === 402, `402 kutilgan, status=${r.status}`, r.json);
      expect(r.json && r.json.code === 'SUB_EXPIRED', 'code SUB_EXPIRED emas', r.json);
    });

    await step('21. A: C raqamiga hamkor yaratadi (A faol — 201)', async () => {
      const r = await A('POST', '/api/partners', { name: 'TEST-E2E Expired Cp', counterparty_phone: '998900000003' });
      if (r.status === 409) throw new Error('409 — oldingi test qoldig\'i bor: avval cleanup SQL\'ni bajaring');
      expect(r.status === 201 && r.json.success, `status=${r.status}`, r.json);
      ctx.pid3 = r.json.data.id;
      return `partner_id=${ctx.pid3}`;
    });

    await step('22. C(expired): POST /api/links/:id/accept -> 200 (javob amali bloklanmaydi)', async () => {
      expect(ctx.pid3, 'pid3 yo\'q (21-qadam yiqilgan)');
      const r = await C('POST', `/api/links/${ctx.pid3}/accept`);
      expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
      expect(r.json.data.link_status === 'accepted', 'accepted emas', r.json.data.link_status);
    });

    await step('22b. A: yangi qarz 70 000 -> pending (twoSided)', async () => {
      const r = await A('POST', `/api/debts/${ctx.pid3}`, { direction: 'toMe', amount: 70000, currency: 'UZS' });
      expect(r.status === 201 && r.json.success, `status=${r.status}`, r.json);
      expect(r.json.data.status === 'pending', 'pending emas', r.json.data.status);
      ctx.debt3 = r.json.data.id;
    });

    await step('23. C(expired): POST /api/debts/:id/confirm -> 200 (qarshi tomon tasdig\'i OCHIQ)', async () => {
      expect(ctx.debt3, 'debt3 yo\'q (22b yiqilgan)');
      const r = await C('POST', `/api/debts/${ctx.debt3}/confirm`);
      expect(r.status === 200 && r.json.success, `status=${r.status}`, r.json);
      expect(r.json.data.status === 'active', 'active emas', r.json.data.status);
    });

    await step('23b. C(expired): repay -> 402; yangi qarz -> 402; xabar -> 402', async () => {
      const r1 = await C('POST', `/api/debts/${ctx.pid3}/repay`, { ref_id: ctx.debt3, amount: 10000 });
      expect(r1.status === 402, `repay: 402 kutilgan, status=${r1.status}`, r1.json);
      const r2 = await C('POST', `/api/debts/${ctx.pid3}`, { direction: 'fromMe', amount: 5000 });
      expect(r2.status === 402, `yangi qarz: 402 kutilgan, status=${r2.status}`, r2.json);
      const r3 = await C('POST', `/api/messages/${ctx.pid3}`, { kind: 'text', body: 'TEST-E2E expired xabar' });
      expect(r3.status === 402, `xabar: 402 kutilgan, status=${r3.status}`, r3.json);
    });

    await step('23c. C(expired): GET /api/debts va /api/links OCHIQ (read-only ko\'rish)', async () => {
      const r1 = await C('GET', `/api/debts/${ctx.pid3}`);
      expect(r1.status === 200 && r1.json.success, `debts GET status=${r1.status}`, r1.json);
      const r2 = await C('GET', '/api/links');
      expect(r2.status === 200 && r2.json.success, `links GET status=${r2.status}`, r2.json);
    });
  }

  // ------------------------------------------------------------------ xulosa
  const pass = results.filter((r) => r.ok).length;
  const fail = results.length - pass;
  console.log(`%c=== E2E yakun: ${pass} PASS, ${fail} FAIL (jami ${results.length}) ===`,
    `color:${fail ? 'red' : 'green'};font-size:14px;font-weight:bold`);
  if (fail) console.table(results.filter((r) => !r.ok));
  console.log('Eslatma: yakunda Supabase\'da cleanup SQL\'ni bajaring (hisobotda).');
})();
