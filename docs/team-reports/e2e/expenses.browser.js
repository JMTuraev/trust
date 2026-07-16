// ============================================================================
// Trust — XARAJAT (expenses/categories) LIVE E2E — brauzer konsoli skripti
// ----------------------------------------------------------------------------
// ISHLATISH:
//   1. Brauzerda https://trust-backend-ft1s.onrender.com/health ni oching
//      (relative fetch'lar shu origin'ga ketadi).
//   2. DevTools Console'ga shu faylni TO'LIQ qo'ying.
//   3. TOKEN ga haqiqiy JWT qo'ying (mobil login access_token yoki
//      POST /api/auth/verify-otp javobidan) va Enter bosing.
//   4. Natija: har qadam PASS / FAIL / WARN, oxirida xulosa + tozalash holati.
//
// MUHIM: skript faqat "TEST:" belgili yozuvlar va "TEST Papka E2E*" toifalar
// yaratadi. Yozuvlar oxirida o'chiriladi; toifani API o'chirmaydi (dizayn:
// arxivlash bor, o'chirish yo'q) — to'liq tozalash SQL hisobotda.
// ============================================================================

const TOKEN = '<<PASTE_JWT>>';

(async () => {
  const H = { 'Content-Type': 'application/json', Authorization: `Bearer ${TOKEN}` };
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const results = [];
  let step = 0;

  const log = (status, name, detail = '') => {
    results.push({ status, name, detail });
    const icon = status === 'PASS' ? '✅' : status === 'WARN' ? '🟡' : '❌';
    console.log(`${icon} ${String(++step).padStart(2, '0')}. [${status}] ${name}${detail ? ' — ' + detail : ''}`);
  };

  const call = async (method, path, body) => {
    const res = await fetch(path, {
      method,
      headers: H,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    let json = {};
    try { json = await res.json(); } catch (_) { /* bo'sh javob */ }
    return { status: res.status, ok: res.ok && json?.success !== false, data: json?.data, error: json?.error };
  };

  // Tozalash ro'yxati (yaratilgan TEST resurslar)
  const createdExpenseIds = [];
  let testCatId = null;

  try {
    // ---- 0. Server tirik ----
    const health = await fetch('/health').then((r) => r.json()).catch(() => null);
    if (health?.ok) log('PASS', 'GET /health', `service=${health.service} v${health.version}`);
    else { log('FAIL', 'GET /health', 'server javob bermadi'); return; }

    // ---- 1. Token yaroqli ----
    const me = await call('GET', '/api/profile/me');
    if (me.ok && me.data?.id) log('PASS', 'GET /api/profile/me (token)', `user=${me.data.id.slice(0, 8)}…`);
    else { log('FAIL', 'GET /api/profile/me', `status=${me.status} ${me.error || ''} — TOKEN'ni tekshiring`); return; }
    await sleep(300);

    // ---- 2. Toifalar seed (7 baza) ----
    const cats = await call('GET', '/api/categories');
    const catNames = (cats.data || []).map((c) => c.name);
    if (cats.ok && catNames.includes('Boshqa') && catNames.includes('Transport') && catNames.length >= 7) {
      log('PASS', 'GET /api/categories (seed 7 baza)', catNames.join(', '));
    } else log('FAIL', 'GET /api/categories', `status=${cats.status} names=[${catNames.join(',')}]`);
    await sleep(300);

    // ---- 3. ?all=1 (arxiv holati bilan) — YANGI endpoint xatti-harakati ----
    const catsAll = await call('GET', '/api/categories?all=1');
    if (catsAll.ok && Array.isArray(catsAll.data) && catsAll.data.every((c) => 'archived' in c)) {
      log('PASS', 'GET /api/categories?all=1', `${catsAll.data.length} toifa, archived maydoni bor`);
    } else log('WARN', 'GET /api/categories?all=1', 'eski backend bo\'lishi mumkin (deploydan keyin qayta tekshiring)');
    await sleep(300);

    // ---- 4. Jonli preview (input rangi manbai): aralash gap in/out ----
    const pv = await call('POST', '/api/expenses/preview', { text: 'oylik oldim 4 mln kreditga 200 ming berdim' });
    const am = pv.data?.amounts || [];
    if (pv.ok && am.length === 2 && am[0].amount === 4000000 && am[1].amount === 200000
        && am[0].kind === 'in' && am[1].kind === 'out') {
      log('PASS', 'POST /preview (aralash gap: 4 mln IN, 200 ming OUT)', `provider=${pv.data.provider}`);
    } else if (pv.ok && am.length === 2) {
      log('WARN', 'POST /preview', `kinds=${am.map((a) => a.kind).join(',')} provider=${pv.data?.provider} — LLM zaxirada bo'lsa qoida-parser javobi`);
    } else log('FAIL', 'POST /preview', `status=${pv.status} ${pv.error || JSON.stringify(pv.data)}`);
    await sleep(300);

    // ---- 5. Parse (uch signal) ----
    const pr = await call('POST', '/api/expenses/parse', { text: 'TEST: taksiga 25 ming berdim' });
    const a0 = pr.data?.actions?.[0];
    if (pr.ok && a0 && a0.direction === 'xarajat' && a0.amount === 25000) {
      const catOk = a0.category === 'Transport';
      log(catOk ? 'PASS' : 'WARN', 'POST /parse (taksiga 25 ming)',
        `direction=${a0.direction} amount=${a0.amount} category=${a0.category} provider=${pr.data.provider}`);
    } else log('FAIL', 'POST /parse', `status=${pr.status} ${pr.error || JSON.stringify(pr.data)}`);
    await sleep(300);

    // ---- 6. Confirm -> saqlash ----
    const cf = await call('POST', '/api/expenses/confirm', {
      text: 'TEST: taksiga 25 ming berdim', source: 'text',
      actions: [a0 || { direction: 'xarajat', amount: 25000, currency: 'UZS', category: 'Transport', note: 'TEST: taksiga 25 ming berdim' }],
    });
    const savedRow = cf.data?.saved?.[0];
    if (cf.ok && savedRow?.id && savedRow.income === false) {
      createdExpenseIds.push(savedRow.id);
      log('PASS', 'POST /confirm (chiqim saqlandi)', `id=${savedRow.id.slice(0, 8)}… category=${savedRow.category} amount=${savedRow.amount}`);
    } else { log('FAIL', 'POST /confirm', `status=${cf.status} ${cf.error || JSON.stringify(cf.data)}`); }
    await sleep(300);

    // ---- 7. GET /expenses ro'yxatda ko'rinadi (+ limit param) ----
    const list = await call('GET', '/api/expenses?limit=50');
    const found = (list.data || []).some((e) => e.id === savedRow?.id);
    if (list.ok && found) log('PASS', 'GET /api/expenses?limit=50 (yozuv ro\'yxatda)');
    else log('FAIL', 'GET /api/expenses', `status=${list.status} found=${found}`);
    await sleep(300);

    // ---- 8. Yangi toifa (papka) yaratish ----
    let nc = await call('POST', '/api/categories', { name: 'TEST Papka E2E' });
    if (nc.status === 409) {
      const allC = await call('GET', '/api/categories?all=1');
      const old = (allC.data || []).find((c) => c.name === 'TEST Papka E2E' || c.name === 'TEST Papka E2E 2');
      if (old) { nc = { ok: true, data: old }; }
    }
    if (nc.ok && nc.data?.id) {
      testCatId = nc.data.id;
      log('PASS', 'POST /api/categories (TEST Papka E2E)', `id=${testCatId.slice(0, 8)}…`);
    } else log('FAIL', 'POST /api/categories', `status=${nc.status} ${nc.error || ''}`);
    await sleep(300);

    // ---- 9. Yozuvni papkaga KO'CHIRISH (manual kategoriya o'zgartirish) ----
    if (savedRow?.id && testCatId) {
      // arxivda bo'lsa avval qaytaramiz (409/renamed holatlarda)
      await call('PATCH', `/api/categories/${testCatId}`, { archived: false });
      await call('PATCH', `/api/categories/${testCatId}`, { name: 'TEST Papka E2E' }).catch(() => {});
      const mv = await call('PATCH', `/api/expenses/${savedRow.id}`, { category: 'TEST Papka E2E' });
      if (mv.ok && mv.data?.category === 'TEST Papka E2E') {
        log('PASS', 'PATCH /expenses/:id (papkaga ko\'chirish)', `category=${mv.data.category}`);
      } else log('FAIL', 'PATCH /expenses/:id (move)', `status=${mv.status} category=${mv.data?.category} ${mv.error || ''}`);
    }
    await sleep(300);

    // ---- 10. Toifani QAYTA NOMLASH -> tarix (expenses) birga ko'chishi (KASKAD) ----
    if (testCatId) {
      const rn = await call('PATCH', `/api/categories/${testCatId}`, { name: 'TEST Papka E2E 2' });
      if (rn.ok && rn.data?.name === 'TEST Papka E2E 2') {
        await sleep(400);
        const after = await call('GET', `/api/expenses?category=${encodeURIComponent('TEST Papka E2E 2')}&limit=10`);
        const moved = (after.data || []).some((e) => e.id === savedRow?.id);
        if (moved) log('PASS', 'PATCH /categories/:id rename + KASKAD (yozuv yangi nomga o\'tdi)');
        else log('FAIL', 'rename KASKADI', 'yozuv eski nomda qoldi — kaskad ishlamadi (yangi kod deploy qilinganmi?)');
      } else log('FAIL', 'PATCH /categories/:id rename', `status=${rn.status} ${rn.error || ''}`);
    }
    await sleep(300);

    // ---- 11. Arxivlash: faol ro'yxatdan chiqadi, ?all=1 da archived=true ----
    if (testCatId) {
      const ar = await call('PATCH', `/api/categories/${testCatId}`, { archived: true });
      await sleep(300);
      const act = await call('GET', '/api/categories');
      const gone = !(act.data || []).some((c) => c.id === testCatId);
      const all2 = await call('GET', '/api/categories?all=1');
      const inAll = (all2.data || []).find((c) => c.id === testCatId);
      if (ar.ok && gone && inAll?.archived === true) {
        log('PASS', 'Arxivlash (faoldan chiqdi, ?all=1 da archived=true)');
      } else log(inAll ? 'FAIL' : 'WARN', 'Arxivlash', `gone=${gone} inAll.archived=${inAll?.archived}`);
    }
    await sleep(300);

    // ---- 12. income flip guard: d->x toifasiz 'Daromad' bo'lib qolmasin ----
    if (savedRow?.id) {
      await call('PATCH', `/api/expenses/${savedRow.id}`, { income: true });
      await sleep(250);
      const back = await call('PATCH', `/api/expenses/${savedRow.id}`, { income: false });
      if (back.ok && back.data?.category === 'Boshqa') {
        log('PASS', 'PATCH income flip guard (d->x, toifasiz => Boshqa)');
      } else log('FAIL', 'PATCH income flip guard', `category=${back.data?.category} (kutilgan: Boshqa)`);
    }
    await sleep(300);

    // ---- 13. QARZ iborasi: expenses'ga YOZILMAYDI, routed bo'lib qaytadi ----
    const qp = await call('POST', '/api/expenses/parse', { text: 'TEST: Anvarga 500 ming qarz berdim' });
    const qa = qp.data?.actions?.[0];
    if (qp.ok && qa && qa.direction === 'qarz_berdim') {
      const qc = await call('POST', '/api/expenses/confirm', {
        text: 'TEST: Anvarga 500 ming qarz berdim', source: 'text', actions: [qa],
      });
      const routedOk = (qc.data?.routed || []).length === 1 && (qc.data?.saved || []).length === 0;
      if (qc.ok && routedOk) {
        log('PASS', 'QARZ marshruti (saved=0, routed=1 — Hamkorlar oqimiga)', `person=${qc.data.routed[0].person || '—'}`);
      } else log('FAIL', 'QARZ marshruti', `saved=${qc.data?.saved?.length} routed=${qc.data?.routed?.length}`);
    } else {
      log(qa ? 'WARN' : 'FAIL', 'POST /parse (qarz iborasi)', `direction=${qa?.direction || '—'} provider=${qp.data?.provider || '?'}`);
    }
    await sleep(300);

    // ---- 14. Himoya: 'Boshqa'ni qayta nomlash TAQIQLANGAN ----
    const bosh = (cats.data || []).find((c) => c.name === 'Boshqa');
    if (bosh) {
      const rb = await call('PATCH', `/api/categories/${bosh.id}`, { name: 'TEST buzish' });
      if (rb.status === 400) log('PASS', "Guard: «Boshqa» rename => 400");
      else log('WARN', "Guard: «Boshqa» rename", `status=${rb.status} — yangi kod hali deploy qilinmagan bo'lishi mumkin`);
    }
    await sleep(300);

    // ---- 15. TOZALASH: TEST yozuvlarni o'chirish ----
    let cleaned = 0;
    for (const id of createdExpenseIds) {
      const del = await call('DELETE', `/api/expenses/${id}`);
      if (del.ok) cleaned++;
      await sleep(200);
    }
    log(cleaned === createdExpenseIds.length ? 'PASS' : 'WARN',
      `Tozalash: ${cleaned}/${createdExpenseIds.length} TEST yozuv o'chirildi`,
      "toifa API orqali o'chirilmaydi (dizayn) — arxivlangan holda qoladi; to'liq SQL hisobotda");
  } catch (err) {
    log('FAIL', 'Kutilmagan xato', String(err));
  }

  // ---- Xulosa ----
  const pass = results.filter((r) => r.status === 'PASS').length;
  const warn = results.filter((r) => r.status === 'WARN').length;
  const fail = results.filter((r) => r.status === 'FAIL').length;
  console.log('—'.repeat(60));
  console.log(`XULOSA: ✅ PASS=${pass}  🟡 WARN=${warn}  ❌ FAIL=${fail}`);
  console.table(results);
})();
