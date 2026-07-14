
class Component extends DCLogic {
  state = {
    stage: 'welcome', lang: 'uz', dark: false, phone: '', otpVal: '', pinVal: '',
    xarTab: 'chat', xarPeriod: 'oy', voiceStage: null, vText: '', xarText: '',
    xarLimit: 3000000, limEdit: null,
    xarEntries: [
      { id: 'x1', kind: 'x', cat: 'Oziq-ovqat', note: 'Bozorlik', a: 85000, days: 0, t: '09:40' },
      { id: 'x2', kind: 'x', cat: 'Transport', note: 'Taksi', a: 25000, days: 1, t: '18:22' },
      { id: 'x3', kind: 'd', cat: 'Daromad', note: 'Oylik', a: 5000000, days: 2, t: '12:05' },
      { id: 'x4', kind: 'x', cat: "Ko'ngilochar", note: 'Kino', a: 60000, days: 3, t: '20:15' },
      { id: 'x5', kind: 'x', cat: 'Salomatlik', note: 'Dori-darmon', a: 42000, days: 5, t: '11:30' },
      { id: 'x6', kind: 'x', cat: 'Kommunal', note: 'Internet', a: 89000, days: 6, t: '09:00' },
      { id: 'x7', kind: 'x', cat: 'Kiyim', note: "Ko'ylak", a: 180000, days: 12, t: '16:45' },
      { id: 'x8', kind: 'x', cat: 'Oziq-ovqat', note: 'Oylik bozorlik', a: 230000, days: 20, t: '10:20' },
      { id: 'x9', kind: 'd', cat: 'Daromad', note: 'Frilans loyiha', a: 1200000, days: 45, t: '14:00' },
      { id: 'x10', kind: 'x', cat: 'Transport', note: 'Benzin', a: 300000, days: 90, t: '08:15' }
    ],
    screen: 'home', clientId: null, tab: 'chat',
    sheetOpen: false, sheetMode: 'client', sheetClient: 'c1',
    receiptId: null, search: '', chatInput: '', codeInput: '', codeError: false, toast: '',
    notifOpen: false, pushOpen: false, confirmId: null, cfVal: '', cfError: false,
    editFormOpen: false, editA: '', editNote: '', reviewId: null, pdfOpen: false,
    playing: null, recOn: false, remTimes: {}, revealed: {}, pinOn: true, notifOn: true, flipped: false,
    cMenuOpen: false, cRen: null, pProfOpen: false,
    skelHome: false, skelOps: false, homeVis: 6, opsVis: 8,
    swipeId: null, swipeDx: 0, swipeSnap: null,
    npOpen: false, npName: '', npPhone: '', npType: 'on',
    homeLoadingMore: false, opsLoadingMore: false,
    onbCc: '+998', npCc: '+998', ccOpen: null, ccSearch: '',
    form: { type: 'Qarz berdim', amount: '', currency: 'UZS', note: '', name: '' },
    clients: [
      { id: 'c1', name: 'Akmal Karimov', phone: '+998 91 234 56 78', onTrust: true },
      { id: 'c2', name: 'Dilnoza Yusupova', phone: '+998 93 456 78 12', onTrust: true },
      { id: 'c3', name: 'Bobur Rahimov', phone: '+998 90 765 43 21', onTrust: true },
      { id: 'c4', name: 'Sardor Aliyev', phone: '+998 97 111 22 33', onTrust: true },
      { id: 'c5', name: 'Malika opa', phone: '+998 88 300 40 50', onTrust: true },
      { id: 'c6', name: "Qo'shni Karim", phone: '+998 94 210 33 08', onTrust: false },
      { id: 'c7', name: 'Oybek (jiyan)', phone: '+998 99 512 74 40', onTrust: false },
      { id: 'c8', name: "Zafar aka (do'kon)", phone: '+998 95 601 18 25', onTrust: false }
    ],
    txs: [
      { id: 't1', c: 'c1', type: 'Qarz berdim', a: 2000000, cur: 'UZS', date: '12-may', code: '51274', st: 'ok', by: 'me' },
      { id: 't2', c: 'c1', type: 'Qarz berdim', a: 1000000, cur: 'UZS', date: '2-iyun', code: '71346', st: 'ok', by: 'me' },
      { id: 't3', c: 'c1', type: "To'lov oldim", a: 600000, cur: 'UZS', date: '28-iyun', code: '90835', st: 'ok', by: 'them' },
      { id: 't4', c: 'c1', type: "To'lov oldim", a: 400000, cur: 'UZS', date: 'Bugun', code: '90462', st: 'pending', by: 'them' },
      { id: 't5', c: 'c2', type: 'Qarz oldim', a: 350000, cur: 'UZS', date: '20-iyun', code: '33581', st: 'ok', by: 'them' },
      { id: 't6', c: 'c3', type: 'Qarz berdim', a: 1150000, cur: 'UZS', date: '5-iyul', code: '88127', st: 'ok', by: 'me' },
      { id: 't7', c: 'c5', type: 'Qarz berdim', a: 120, cur: 'USD', date: '30-iyun', code: '22643', st: 'ok', by: 'me' },
      { id: 't8', c: 'c4', type: 'Qarz berdim', a: 500000, cur: 'UZS', date: '3-aprel', code: '66125', st: 'ok', by: 'me' },
      { id: 't9', c: 'c4', type: "To'lov oldim", a: 500000, cur: 'UZS', date: '30-aprel', code: '11478', st: 'ok', by: 'them' },
      { id: 't10', c: 'c1', type: 'Qarz oldim', a: 500000, cur: 'UZS', date: 'Bugun', code: '48215', st: 'pending', by: 'them' },
      { id: 't11', c: 'c6', type: 'Qarz berdim', a: 50000, cur: 'UZS', date: '8-iyul', code: '', st: 'unconf', by: 'me' },
      { id: 't12', c: 'c7', type: 'Qarz berdim', a: 15, cur: 'USD', date: '1-iyul', code: '', st: 'unconf', by: 'me' },
      { id: 't13', c: 'c8', type: 'Qarz oldim', a: 200000, cur: 'UZS', date: '11-iyul', code: '', st: 'unconf', by: 'me' }
    ],
    msgs: {
      c1: [
        { k: 'text', mine: false, text: 'Assalomu alaykum, Jasur aka', time: '09:12' },
        { k: 'text', mine: true, text: 'Vaalaykum assalom, Akmal', time: '09:14', read: true },
        { k: 'voice', mine: false, dur: 12, time: '09:15' },
        { k: 'voice', mine: true, dur: 7, time: '09:16', read: true },
        { k: 'vnote', mine: false, dur: 23, time: '09:18' },
        { k: 'text', mine: false, text: "400 ming to'lov qildim, tasdiqlab bering", time: '09:20' },
        { k: 'tx', tx: 't4' },
        { k: 'code', mine: false, code: '90462', time: '09:21' },
        { k: 'tx', tx: 't10' },
        { k: 'text', mine: true, text: 'Hozir tekshiraman', time: '09:22', read: false }
      ],
      c2: [
        { k: 'text', mine: false, text: "Oyning 15-igacha qaytaraman, xavotir olmang", time: '18:02' },
        { k: 'tx', tx: 't5' }
      ],
      c3: [{ k: 'tx', tx: 't6' }],
      c4: [
        { k: 'tx', tx: 't8' },
        { k: 'tx', tx: 't9' },
        { k: 'text', mine: false, text: 'Rahmat, hisob teng!', time: '12:40' }
      ],
      c5: [{ k: 'tx', tx: 't7' }],
      c6: [{ k: 'tx', tx: 't11' }],
      c7: [{ k: 'tx', tx: 't12' }],
      c8: [
        { k: 'tx', tx: 't13' },
        { k: 'text', mine: true, text: "Do'kondan olingan mol uchun yozib qo'ydim", time: '11-iyul', read: false }
      ]
    },

    notifs: [
      { id: 'n1', kind: 'request', unread: true, title: "Tasdiq so'rovi", detail: "Akmal Karimov · 500 000 so'm · kod kerak", time: 'Hozir', tx: 't10' },
      { id: 'n2', kind: 'confirmed', unread: true, title: 'Tasdiqlandi', detail: "Bobur Rahimov 1 150 000 so'm amalini tasdiqladi", time: 'Kecha', tx: 't6' },
      { id: 'n3', kind: 'reminder', unread: false, title: 'Eslatma', detail: "Dilnoza Yusupova · 350 000 so'm · muddat: 15-iyul", time: '2 kun oldin', client: 'c2' }
    ]
  };

  toast_(msg) {
    clearTimeout(this._tt);
    this.setState({ toast: msg });
    this._tt = setTimeout(() => this.setState({ toast: '' }), 2200);
  }

  // Tungi rejim (dark mode) — theme vars on body.dark
  componentDidMount() {
    let d = false;
    try { d = localStorage.getItem('trust_dark') === '1'; } catch (e) {}
    document.body.classList.toggle('dark', d);
    if (d !== this.state.dark) this.setState({ dark: d });
    this._cd = setInterval(() => {
      const r = this.state.remTimes || {};
      if (Object.keys(r).length) this.forceUpdate();
    }, 1000);
  }

  replyFrom(cid, text, delay) {
    setTimeout(() => {
      const S = this.state;
      const fl = !!S.flipped && S.clientId === cid;
      const msgs = { ...S.msgs };
      const arr = (msgs[cid] || []).map(m => (m.mine !== fl) ? { ...m, read: true } : m);
      arr.push({ k: 'text', mine: fl, text, time: 'Hozir' });
      msgs[cid] = arr;
      this.setState({ msgs });
    }, delay || 1500);
  }

  setDark(d) {
    try { localStorage.setItem('trust_dark', d ? '1' : '0'); } catch (e) {}
    document.body.classList.toggle('dark', d);
    this.setState({ dark: d });
  }

  L() {
    const uz = {
      slogan: "«Hisobli do'st — ayrilmas»",
      tagline: "Qarz va hisob-kitoblaringizni ikki tomonlama tasdiq bilan yuriting. Har bir yozuv — o'chirilmas halol dalil.",
      start: 'Boshlash', terms: 'Davom etish orqali foydalanish shartlariga rozilik bildirasiz',
      phoneTitle: 'Telefon raqami', phoneSub: "Hisobingiz shu raqamga bog'lanadi", cont: 'Davom etish',
      otpTitle: 'Tasdiqlash kodi', otpDemo: 'Demo: istalgan 5 raqam qabul qilinadi', confirm: 'Tasdiqlash',
      pinTitle: "PIN o'rnating", pinSub: 'Ilovaga kirish uchun 4 xonali kod',
      appSub: 'Ishonchli hisob-kitob', netCap: 'SOF BALANS', owedTo: 'Sizga qarz', owedBy: 'Qarzingiz', searchPh: 'Qidirish',
      navClients: 'Hamkorlar', navBook: 'Daftar', navFin: 'Moliya', navProfile: 'Profil',
      tabChat: 'Chat', tabOps: 'Operatsiyalar', opCap: 'Operatsiya',
      codePrompt: 'Tasdiqlash uchun chatdagi 5 xonali kodni kiriting',
      codeWrong: "Kod noto'g'ri. Qayta urinib ko'ring.",
      myCode: 'Tasdiqlash kodi — ikkinchi tomon kiritadi',
      openDalil: 'Dalilni ochish', msgPh: 'Xabar yozing',
      receiptTitle: 'Dalil', lockedCap: 'QULFLANGAN YOZUV', from: 'Kimdan', to: 'Kimga', date: 'Sana',
      codeLabel: 'Tasdiqlash kodi', statusL: 'Holat', statusVal: 'Ikki tomonlama tasdiqlangan',
      receiptNote: "Ushbu yozuv o'chirib bo'lmaydi. O'zgartirish faqat ikki tomon roziligi bilan amalga oshiriladi.",
      share: 'Ulashish (PDF)', changeReq: "O'zgartirish so'rovi", archive: 'Arxivlash',
      bookTitle: 'Bir tomonlama daftar',
      bookDesc: "Ikkinchi tomon Trust'da yo'q. Bu yozuvlar tasdiqsiz — dalil kuchiga ega emas.",
      unconfirmed: 'tasdiqsiz',
      bookInvite: "Qarzdorni Trust'ga taklif qiling — yozuv ikki tomonlama tasdiqlanadi va dalilga aylanadi.",
      newEntry: '+ Yangi yozuv',
      finTitle: 'Moliya', turnover: 'OYLIK AYLANMA', mlnHint: "mln so'm hisobida", remindersCap: 'ESLATMALAR', remind: 'Eslatish',
      given: 'Berilgan qarzlar', taken: 'Olingan qarzlar', repaid: "Qaytarilgan to'lovlar", netLabel: 'Sof balans',
      logout: 'Chiqish',
      clientCap: 'HAMKOR', withWhom: 'KIM BILAN', typeCap: 'TURI', sumCap: 'SUMMA', noteCap: 'IZOH',
      namePh: 'Ism yozing', notePh: 'Masalan: mol savdosi uchun',
      sheetNew: 'Yangi operatsiya', sheetNewBook: 'Yangi tasdiqsiz yozuv', makeCode: 'Kod yaratish', saveUnconf: 'Saqlash (tasdiqsiz)',
      hintClient: "Kod chatda ko'rinadi. Ikkinchi tomon kodni kiritgach, yozuv qulflanadi.",
      hintBook: 'Bu yozuv faqat sizning daftaringizda saqlanadi — dalil emas.',
      balPfx: 'Balans: ', stPending: 'Kutilmoqda', stOk: 'Tasdiqlangan', stArch: 'Arxivda', kod: 'kod',
      me: 'Jasur Toshmatov (siz)', last: "So'nggi: ", noOps: "Amaliyot yo'q",
      subPos: 'sizga qarz', subNeg: 'siz qarzsiz', subZero: 'hisob teng', zero: "0 so'm", som: "so'm", due: 'muddat',
      sysDone: 'Ikki tomonlama tasdiqlandi · Dalil yaratildi',
      tCode: 'Kod yaratildi — ', tSaved: 'Tasdiqsiz yozuv saqlandi', tDalil: 'Dalil yaratildi',
      tPdf: 'PDF dalil tayyorlanmoqda…', tReqPre: "So'rov yuborildi — ", tReqSuf: ' tasdiqlashi kerak',
      tArch: "Arxivga ko'chirildi", tRemind: 'Eslatma yuborildi', tWelcome: 'Xush kelibsiz, Jasur!',
      tSum: 'Summani kiriting', tNum: "Raqamni to'liq kiriting", tEnterCode: 'Kodni kiriting',
      profTil: 'Til', profTilVal: "O'zbek (lotin)", profCur: 'Asosiy valyuta', profPin: 'PIN-kod',
      profNotif: 'Bildirishnomalar', profArch: 'Arxivlangan yozuvlar', on: 'Yoqilgan',
      otpSent: p => '+998 ' + p + ' raqamiga yuborildi'
    };
    const ru = {
      slogan: '«Счёт дружбы не портит»',
      tagline: 'Записывайте долги с подтверждением обеих сторон. Каждая запись — честное доказательство, которое нельзя удалить.',
      start: 'Начать', terms: 'Продолжая, вы соглашаетесь с условиями использования',
      phoneTitle: 'Номер телефона', phoneSub: 'Аккаунт будет привязан к этому номеру', cont: 'Продолжить',
      otpTitle: 'Код подтверждения', otpDemo: 'Демо: подойдут любые 4 цифры', confirm: 'Подтвердить',
      pinTitle: 'Установите PIN', pinSub: 'Код из 4 цифр для входа в приложение',
      appSub: 'учёт долгов', netCap: 'ЧИСТЫЙ БАЛАНС', owedTo: 'Вам должны', owedBy: 'Вы должны', searchPh: 'Поиск',
      navClients: 'Клиенты', navBook: 'Тетрадь', navFin: 'Финансы', navProfile: 'Профиль',
      tabChat: 'Чат', tabOps: 'Операции', opCap: 'Операция',
      codePrompt: 'Введите 5-значный код из чата, чтобы подтвердить',
      codeWrong: 'Неверный код. Попробуйте ещё раз.',
      myCode: 'Код подтверждения — вводит вторая сторона',
      openDalil: 'Открыть далил', msgPh: 'Напишите сообщение',
      receiptTitle: 'Далил', lockedCap: 'ЗАЩИЩЁННАЯ ЗАПИСЬ', from: 'От кого', to: 'Кому', date: 'Дата',
      codeLabel: 'Код подтверждения', statusL: 'Статус', statusVal: 'Подтверждено обеими сторонами',
      receiptNote: 'Эту запись нельзя удалить. Изменения — только с согласия обеих сторон.',
      share: 'Поделиться (PDF)', changeReq: 'Запрос на изменение', archive: 'В архив',
      bookTitle: 'Односторонняя тетрадь',
      bookDesc: 'Второй стороны нет в Trust. Записи без подтверждения не имеют силы далила.',
      unconfirmed: 'не подтв.',
      bookInvite: 'Пригласите должника в Trust — запись подтвердится обеими сторонами и станет далилом.',
      newEntry: '+ Новая запись',
      finTitle: 'Финансы', turnover: 'ОБОРОТ ПО МЕСЯЦАМ', mlnHint: 'в млн сумов', remindersCap: 'НАПОМИНАНИЯ', remind: 'Напомнить',
      given: 'Выдано в долг', taken: 'Взято в долг', repaid: 'Возвращено', netLabel: 'Чистый баланс',
      logout: 'Выйти',
      clientCap: 'КЛИЕНТ', withWhom: 'С КЕМ', typeCap: 'ТИП', sumCap: 'СУММА', noteCap: 'КОММЕНТАРИЙ',
      namePh: 'Введите имя', notePh: 'Например: за товар',
      sheetNew: 'Новая операция', sheetNewBook: 'Запись без подтверждения', makeCode: 'Создать код', saveUnconf: 'Сохранить (без подтв.)',
      hintClient: 'Код появится в чате. Когда вторая сторона введёт код, запись будет заблокирована.',
      hintBook: 'Эта запись хранится только в вашей тетради — это не далил.',
      balPfx: 'Баланс: ', stPending: 'Ожидание', stOk: 'Подтверждено', stArch: 'В архиве', kod: 'код',
      me: 'Жасур Тошматов (вы)', last: 'Последняя: ', noOps: 'Нет операций',
      subPos: 'вам должны', subNeg: 'вы должны', subZero: 'счёт равный', zero: '0 сум', som: 'сум', due: 'срок',
      sysDone: 'Подтверждено обеими сторонами · Далил создан',
      tCode: 'Код создан — ', tSaved: 'Запись сохранена (без подтв.)', tDalil: 'Далил создан',
      tPdf: 'Готовим PDF-далил…', tReqPre: 'Запрос отправлен — нужно подтверждение: ', tReqSuf: '',
      tArch: 'Перенесено в архив', tRemind: 'Напоминание отправлено', tWelcome: 'Добро пожаловать, Жасур!',
      tSum: 'Введите сумму', tNum: 'Введите номер полностью', tEnterCode: 'Введите код',
      profTil: 'Язык', profTilVal: 'Русский', profCur: 'Основная валюта', profPin: 'PIN-код',
      profNotif: 'Уведомления', profArch: 'Записи в архиве', on: 'Включено',
      otpSent: p => 'Код отправлен на +998 ' + p
    };
    return this.state.lang === 'ru' ? ru : uz;
  }

  typeLabel(t) {
    if (this.state.lang !== 'ru') return t;
    return ({ 'Qarz berdim': 'Дал в долг', 'Qarz oldim': 'Взял в долг', "To'lov oldim": 'Получил оплату', "To'lov berdim": 'Отдал оплату' })[t] || t;
  }

  tapKey(field, label) {
    let v = this.state[field];
    if (label === 'del') v = v.slice(0, -1);
    else if (v.length < (field === 'pinVal' ? 4 : 5)) v += label;
    const st = {}; st[field] = v;
    this.setState(st);
    if (field === 'pinVal' && v.length === 4) {
      setTimeout(() => {
        this.setState({ stage: 'app', pinVal: '', skelHome: true, homeVis: 6 });
        setTimeout(() => this.setState({ skelHome: false }), 950);
        this.toast_(this.L().tWelcome);
      }, 280);
    }
  }

  CC = [
    { f: '🇺🇿', n: "O'zbekiston", d: '+998', len: 9, ph: '90 123 45 67' },
    { f: '🇷🇺', n: 'Rossiya', d: '+7', len: 10, ph: '912 345 67 89' },
    { f: '🇹🇷', n: 'Turkiya', d: '+90', len: 10, ph: '501 234 56 78' },
    { f: '🇺🇸', n: 'AQSH', d: '+1', len: 10, ph: '212 555 0123' },
    { f: '🇬🇧', n: 'Buyuk Britaniya', d: '+44', len: 10, ph: '7911 123 456' },
    { f: '🇦🇪', n: 'BAA', d: '+971', len: 9, ph: '50 123 45 67' },
    { f: '🇪🇸', n: 'Ispaniya', d: '+34', len: 9, ph: '612 345 678' },
    { f: '🇮🇳', n: 'Hindiston', d: '+91', len: 10, ph: '98765 43210' },
    { f: '🇨🇳', n: 'Xitoy', d: '+86', len: 11, ph: '138 0013 8000' },
    { f: '🇩🇪', n: 'Germaniya', d: '+49', len: 10, ph: '1512 345 6789' }
  ];

  ccEntry(dial) {
    return this.CC.find(c => c.d === dial) || this.CC[0];
  }

  archive_(id) {
    this.setState({ clients: this.state.clients.map(x => x.id === id ? { ...x, archived: true } : x), swipeSnap: null, swipeId: null, swipeDx: 0 });
    this.toast_(this.L().tArch);
  }

  restore_(id) {
    this.setState({ clients: this.state.clients.map(x => x.id === id ? { ...x, archived: false } : x), swipeSnap: null, swipeId: null, swipeDx: 0 });
    this.toast_('Arxivdan qaytarildi');
  }

  swipe_(id, act) {
    return {
      pd: e => {
        try { e.currentTarget.setPointerCapture(e.pointerId); } catch (err) {}
        this._sw = { id, x0: e.clientX, dx0: this.state.swipeSnap === id ? -96 : 0, moved: false };
        clearTimeout(this._lp);
        this._lp = setTimeout(() => {
          if (this._sw && this._sw.id === id && !this._sw.moved) {
            this._sw = null;
            this.setState({ swipeSnap: id, swipeId: null, swipeDx: 0 });
          }
        }, 480);
      },
      pm: e => {
        if (!this._sw || this._sw.id !== id) return;
        const raw = this._sw.dx0 + (e.clientX - this._sw.x0);
        if (Math.abs(e.clientX - this._sw.x0) > 6) { this._sw.moved = true; clearTimeout(this._lp); }
        if (!this._sw.moved) return;
        this.setState({ swipeId: id, swipeDx: Math.max(-140, Math.min(0, raw)) });
      },
      pu: () => {
        clearTimeout(this._lp);
        if (!this._sw || this._sw.id !== id) return;
        const moved = this._sw.moved;
        this._sw = null;
        if (moved) this._swClick = true;
        const dx = this.state.swipeId === id ? this.state.swipeDx : (this.state.swipeSnap === id ? -96 : 0);
        if (moved && dx < -120) {
          this.setState({ swipeId: null, swipeDx: 0, swipeSnap: null });
          act();
        } else if (moved && dx < -48) {
          this.setState({ swipeSnap: id, swipeId: null, swipeDx: 0 });
        } else if (moved) {
          this.setState({ swipeSnap: this.state.swipeSnap === id ? null : this.state.swipeSnap, swipeId: null, swipeDx: 0 });
        } else {
          this.setState({ swipeId: null, swipeDx: 0 });
        }
      }
    };
  }

  renSave_() {
    const S = this.state;
    if (S.cRen === null) return;
    const v = S.cRen.trim();
    if (!v) { this.setState({ cRen: null }); return; }
    this.setState({ clients: S.clients.map(x => x.id === S.clientId ? { ...x, name: v } : x), cRen: null });
    this.toast_('Nom yangilandi');
  }

  makeKeys(field) {
    return ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'].map(l => ({
      label: l === 'del' ? '⌫' : l,
      tap: l === '' ? (() => {}) : (() => this.tapKey(field, l))
    }));
  }

  confirmTx(id) {
    const S = this.state;
    const t = S.txs.find(x => x.id === id);
    if (S.codeInput.trim() === t.code) {
      const msgs = { ...S.msgs };
      const cc = S.clients.find(x => x.id === t.c);
      msgs[t.c] = [...(msgs[t.c] || []), { k: 'sys', text: cc.name.split(' ')[0] + ' yaratdi (09:20) · Siz kodni kiritdingiz (hozir) · Dalil yaratildi' }];
      this.setState({
        txs: S.txs.map(x => x.id === id ? { ...x, st: 'ok' } : x),
        msgs, codeInput: '', codeError: false
      });
      this.toast_(this.L().tDalil);
      this.replyFrom(t.c, "Rahmat! Hammasi to'g'ri.", 1600);
    } else {
      this.setState({ codeError: true });
    }
  }

  togglePlay(key, dur) {
    const p = this.state.playing;
    if (p && p.key === key && !p.paused) {
      clearInterval(this._pi);
      this.setState({ playing: { ...p, paused: true } });
      return;
    }
    clearInterval(this._pi);
    const start = (p && p.key === key) ? p.prog : 0;
    this.setState({ playing: { key, prog: start, paused: false, dur } });
    this._pi = setInterval(() => {
      const pp = this.state.playing;
      if (!pp || pp.paused) { clearInterval(this._pi); return; }
      const np = pp.prog + 0.1 / dur;
      if (np >= 1) { clearInterval(this._pi); this.setState({ playing: null }); }
      else this.setState({ playing: { ...pp, prog: np } });
    }, 100);
  }

  startRec() {
    if (this.state.recOn) return;
    this.setState({ recOn: true });
    setTimeout(() => {
      const S = this.state;
      if (!S.clientId) { this.setState({ recOn: false }); return; }
      const msgs = { ...S.msgs };
      msgs[S.clientId] = [...(msgs[S.clientId] || []), { k: 'voice', mine: !S.flipped, dur: 7, time: 'Hozir', read: false }];
      this.setState({ recOn: false, msgs });
    }, 1600);
  }

  fmtA(a, cur) { return String(a).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + (cur === 'USD' ? ' $' : " so'm"); }

  submitEdit() {
    const S = this.state;
    const t = S.txs.find(x => x.id === S.receiptId);
    if (!t) return;
    const newA = parseInt(S.editA, 10) || t.a;
    const newNote = S.editNote.trim();
    if (newA === t.a && newNote === (t.note || '')) { this.toast_("O'zgarish kiritilmadi"); return; }
    const c = S.clients.find(x => x.id === t.c);
    const notifs = [{ id: 'n' + Date.now(), kind: 'editreq', unread: true, title: "O'zgartirish so'rovi", detail: c.name + " yozuvni o'zgartirmoqchi: " + this.fmtA(t.a, t.cur) + ' → ' + this.fmtA(newA, t.cur) + '. Tasdiqlaysizmi?', time: 'Hozir', tx: t.id }, ...S.notifs];
    this.setState({
      txs: S.txs.map(x => x.id === t.id ? { ...x, edit: { a: newA, note: newNote, date: '13-iyul' } } : x),
      notifs, editFormOpen: false, editA: '', editNote: ''
    });
    this.toast_("So'rov yuborildi — ikkinchi tomon tasdiqlashi kerak");
  }

  approveEdit() {
    const S = this.state;
    const t = S.txs.find(x => x.id === S.reviewId);
    if (!t || !t.edit) return;
    const line = this.fmtA(t.a, t.cur) + ' → ' + this.fmtA(t.edit.a, t.cur) + ' · ikki tomon tasdiqi · 13-iyul';
    const notifs = [{ id: 'n' + Date.now(), kind: 'confirmed', unread: true, title: "O'zgartirish tasdiqlandi", detail: line, time: 'Hozir', tx: t.id }, ...S.notifs];
    this.setState({
      txs: S.txs.map(x => x.id === t.id ? { ...x, a: t.edit.a, note: t.edit.note || x.note, edit: null, hist: [...(t.hist || []), { txt: line }] } : x),
      notifs, reviewId: null, receiptId: t.id
    });
    this.toast_('Yozuv tuzatildi — tarix saqlandi');
  }

  rejectEdit() {
    const S = this.state;
    const t = S.txs.find(x => x.id === S.reviewId);
    if (!t) return;
    const notifs = [{ id: 'n' + Date.now(), kind: 'rejected', unread: true, title: "O'zgartirish rad etildi", detail: "Asl qiymat o'zgarishsiz qoladi — " + this.fmtA(t.a, t.cur), time: 'Hozir', tx: t.id }, ...S.notifs];
    this.setState({ txs: S.txs.map(x => x.id === t.id ? { ...x, edit: null } : x), notifs, reviewId: null });
    this.toast_('Rad etildi — asl yozuv saqlanadi');
  }

  confirmSecond() {
    const S = this.state;
    const t = S.txs.find(x => x.id === S.confirmId);
    if (!t) return;
    if (S.cfVal === t.code) {
      const c = S.clients.find(x => x.id === t.c);
      const msgs = { ...S.msgs };
      msgs[t.c] = [...(msgs[t.c] || []), { k: 'sys', text: c.name.split(' ')[0] + ' yaratdi (09:41) · Siz tasdiqladingiz (hozir) · Dalil yaratildi' }];
      const amt = String(t.a).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + (t.cur === 'USD' ? ' $' : " so'm");
      const notifs = [
        { id: 'n' + Date.now(), kind: 'confirmed', unread: true, title: 'Tasdiqlandi', detail: c.name + ' bilan ' + amt + ' amali dalilga aylandi', time: 'Hozir', tx: t.id },
        ...S.notifs.map(n => (n.tx === t.id && n.kind === 'request') ? { ...n, unread: false } : n)
      ];
      this.setState({
        txs: S.txs.map(x => x.id === t.id ? { ...x, st: 'ok' } : x),
        msgs, notifs, confirmId: null, cfVal: '', cfError: false, receiptId: t.id
      });
      this.toast_('Dalil yaratildi');
      this.replyFrom(t.c, 'Rahmat, Jasur aka!', 1800);
    } else {
      this.setState({ cfError: true });
    }
  }

  createTx() {
    const S = this.state;
    const f = S.form;
    const a = parseInt(f.amount, 10) || 0;
    if (!a) { this.toast_(this.L().tSum); return; }
    const code = String(Math.floor(10000 + Math.random() * 90000));
    const cl0 = S.clients.find(x => x.id === S.sheetClient);
    const two = cl0 ? cl0.onTrust !== false : true;
    const id = 't' + Date.now();
    const tx = { id, c: S.sheetClient, type: f.type, a, cur: f.currency, date: 'Bugun', code: two ? code : '', st: two ? 'pending' : 'unconf', by: 'me' };
    const msgs = { ...S.msgs };
    msgs[S.sheetClient] = [...(msgs[S.sheetClient] || []), { k: 'tx', tx: id }];
    this.setState({
      txs: [...S.txs, tx], msgs, sheetOpen: false,
      clientId: S.sheetClient, tab: 'chat',
      form: { type: 'Qarz berdim', amount: '', currency: 'UZS', note: '', name: '' }
    });
    if (!two) { this.toast_(this.L().tSaved); return; }
    this.toast_(this.L().tCode + code);
    setTimeout(() => {
      const S2 = this.state;
      const t2 = S2.txs.find(x => x.id === id);
      if (!t2 || t2.st !== 'pending') return;
      const cl = S2.clients.find(x => x.id === t2.c);
      const msgs2 = { ...S2.msgs };
      msgs2[t2.c] = [...(msgs2[t2.c] || []), { k: 'sys', text: cl.name.split(' ')[0] + ' kodni kiritdi (hozir) · Dalil yaratildi' }];
      const notifs2 = [{ id: 'n' + Date.now(), kind: 'confirmed', unread: true, title: 'Tasdiqlandi', detail: cl.name + ' ' + this.fmtA(t2.a, t2.cur) + ' amalini tasdiqladi · hozir', time: 'Hozir', tx: id }, ...S2.notifs];
      this.setState({ txs: S2.txs.map(x => x.id === id ? { ...x, st: 'ok' } : x), msgs: msgs2, notifs: notifs2 });
      this.toast_(cl.name.split(' ')[0] + ' kodni kiritdi — dalil yaratildi');
    }, 4200);
  }

  xarParse_(txt) {
    const t = txt.toLowerCase();
    const m = t.match(/(\d+(?:[.,]\d+)?)/);
    let a = m ? parseFloat(m[1].replace(',', '.')) : 0;
    if (/mln|million|milion/.test(t)) a *= 1000000;
    else if (/ming/.test(t)) a *= 1000;
    a = Math.round(a);
    const inc = /(oylik|maosh|daromad|tushdi|keldi|sotdim|foyda|bonus)/.test(t);
    let cat = inc ? 'Daromad' : 'Boshqa';
    if (!inc) {
      const map = [
        ['Oziq-ovqat', /oziq|ovqat|bozor|non|go'sht|gosht|market|restoran|kafe|choyxona/],
        ['Transport', /taksi|benzin|yo'l|yol|metro|avtobus|mashina/],
        ['Kommunal', /kommunal|svet|elektr|gaz|suv|internet|telefon/],
        ["Ko'ngilochar", /kino|konsert|o'yin|oyin|sayohat|dam olish/],
        ['Kiyim', /kiyim|ko'ylak|koylak|poyabzal|shim|kurtka/],
        ['Salomatlik', /dori|apteka|shifokor|klinika|tish|salomatlik/]
      ];
      for (const [c, re] of map) if (re.test(t)) { cat = c; break; }
    }
    const note = txt.trim().replace(/^./, ch => ch.toUpperCase());
    return { kind: inc ? 'd' : 'x', amount: a ? String(a) : '', cat, note };
  }

  xarPick_(txt) {
    this.setState({ voiceStage: 'parsing', vText: txt, xarText: '' });
    clearTimeout(this._xt);
    this._xt = setTimeout(() => {
      const f = this.xarParse_(txt);
      const a = parseInt(f.amount, 10) || 0;
      if (!a) { this.setState({ voiceStage: null, vText: '' }); this.toast_('Summa aniqlanmadi — masalan: «taksiga 25 ming»'); return; }
      const now = new Date();
      const t = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
      const e = { id: 'xe' + Date.now(), kind: f.kind, cat: f.cat, note: f.note, a, days: 0, t };
      this.setState({ xarEntries: [e, ...this.state.xarEntries], voiceStage: null, vText: '' });
      this.toast_('AI toifaladi: ' + f.cat + ' — chatga yozildi');
    }, 1400);
  }

  limSave_() {
    const v = parseInt(this.state.limEdit, 10) || 0;
    if (!v) { this.toast_('Summani kiriting'); return; }
    this.setState({ xarLimit: v, limEdit: null });
    this.toast_('Oylik limit yangilandi');
  }

  xarVals_(ctx) {
    const S = this.state;
    const { INK, BG, BD, MUT, money, red, green } = ctx;
    const abbr = c => ({ 'Oziq-ovqat': 'Oz', 'Transport': 'Tr', 'Kommunal': 'Km', "Ko'ngilochar": 'Ko', 'Kiyim': 'Ki', 'Salomatlik': 'Sa', 'Boshqa': 'B', 'Daromad': 'Da' })[c] || 'B';
    const MON = ['yan', 'fev', 'mar', 'apr', 'may', 'iyn', 'iyl', 'avg', 'sen', 'okt', 'noy', 'dek'];
    const fmtDay = d => d === 0 ? 'Bugun' : d === 1 ? 'Kecha' : (dt => dt.getDate() + '-' + MON[dt.getMonth()])(new Date(Date.now() - d * 86400000));
    const perDays = S.xarPeriod === 'hafta' ? 7 : S.xarPeriod === 'oy' ? 30 : 365;
    const inP = S.xarEntries.filter(e => e.days < perDays);
    const out = inP.filter(e => e.kind === 'x').reduce((s, e) => s + e.a, 0);
    const inc = inP.filter(e => e.kind === 'd').reduce((s, e) => s + e.a, 0);
    const net = inc - out;
    const XCATS = ['Oziq-ovqat', 'Transport', 'Kommunal', "Ko'ngilochar", 'Kiyim', 'Salomatlik', 'Boshqa'];
    const perCat = XCATS.map(c => ({ c, v: inP.filter(e => e.kind === 'x' && e.cat === c).reduce((s, e) => s + e.a, 0) })).filter(x => x.v > 0).sort((a, b) => b.v - a.v);
    const maxCat = perCat.length ? perCat[0].v : 1;
    const monthOut = S.xarEntries.filter(e => e.kind === 'x' && e.days < 30).reduce((s, e) => s + e.a, 0);
    const lim = S.xarLimit;
    const ratio = lim > 0 ? monthOut / lim : 0;
    const limOver = ratio > 1;
    const limNear = !limOver && ratio >= 0.8;
    const limHot = limOver || limNear;
    const limRem = Math.abs(lim - monthOut);
    return {
      limPct: Math.min(100, Math.round(ratio * 100)),
      limPctTxt: Math.round(ratio * 100) + '%',
      limBar: limHot ? red : INK,
      limRemainC: limHot ? red : MUT,
      limSpentTxt: money(monthOut, 'UZS'),
      limTotTxt: money(lim, 'UZS'),
      limRemainTxt: limOver ? 'Limitdan oshdi' : 'Qoldi: ' + money(limRem, 'UZS'),
      limNoteTxt: limOver ? 'Limitdan oshdi · ' + money(limRem, 'UZS') + ' ortiqcha'
        : limNear ? 'Qoldi: ' + money(limRem, 'UZS') + ' · limitga yaqin'
        : 'Qoldi: ' + money(limRem, 'UZS'),
      limBtnTxt: S.limEdit !== null ? 'Bekor' : "O'zgartirish",
      limEditOpen: S.limEdit !== null,
      limEditVal: S.limEdit ?? '',
      limEditSet: e => this.setState({ limEdit: e.target.value.replace(/[^\d]/g, '') }),
      limEditKey: e => { if (e.key === 'Enter') this.limSave_(); },
      limSave: () => this.limSave_(),
      limEditToggle: () => this.setState({ limEdit: this.state.limEdit === null ? String(this.state.xarLimit) : null }),
      xtChat: S.xarTab === 'chat', xtHisobot: S.xarTab === 'hisobot',
      xarTabs: [['chat', 'Chat'], ['hisobot', 'Hisobotlar']].map(([k, l]) => ({
        label: l, pick: () => this.setState({ xarTab: k }),
        bg: S.xarTab === k ? INK : 'transparent', fg: S.xarTab === k ? BG : MUT
      })),
      xChat: (() => {
        const chron = [...S.xarEntries].reverse();
        chron.sort((a, b) => b.days - a.days);
        const visual = [];
        let lastDay = null;
        chron.forEach(e => {
          if (e.days !== lastDay) {
            const dayD = S.xarEntries.filter(x => x.days === e.days && x.kind === 'd').reduce((s, x) => s + x.a, 0);
            const dayX = S.xarEntries.filter(x => x.days === e.days && x.kind === 'x').reduce((s, x) => s + x.a, 0);
            visual.push({
              sep: true, bub: false, label: fmtDay(e.days),
              dTxt: '+' + money(dayD, 'UZS'), dColor: dayD > 0 ? green : MUT,
              xTxt: '−' + money(dayX, 'UZS'), xColor: dayX > 0 ? red : MUT
            });
            lastDay = e.days;
          }
          const isD = e.kind === 'd';
          visual.push({
            sep: false, bub: true,
            just: isD ? 'flex-start' : 'flex-end',
            rad: isD ? '4px 16px 16px 16px' : '16px 4px 16px 16px',
            abbr: abbr(e.cat), cat: e.cat.toUpperCase(),
            amt: (isD ? '+' : '−') + money(e.a, 'UZS'),
            color: isD ? green : red,
            note: e.note, hasNote: !!e.note && e.note.toLowerCase() !== e.cat.toLowerCase(),
            time: e.t || ''
          });
        });
        return visual.reverse();
      })(),
      xHasText: !!S.xarText.trim(),
      xarKey: e => { if (e.key === 'Enter') { const t = this.state.xarText.trim(); if (t) this.xarPick_(t); } },
      xTrend: (() => {
        const sums = [0, 1, 2, 3, 4, 5].map(i => S.xarEntries.filter(e => e.kind === 'x' && e.days >= i * 30 && e.days < (i + 1) * 30).reduce((s, e) => s + e.a, 0));
        const maxTr = Math.max(...sums, 1);
        const nowM = new Date().getMonth();
        return [5, 4, 3, 2, 1, 0].map(i => ({
          label: MON[(nowM - i + 12) % 12].replace(/^./, c => c.toUpperCase()),
          val: ctx.priv ? '•' : String(Math.round(sums[i] / 1000)),
          h: Math.max(4, Math.round(sums[i] / maxTr * 72)),
          bg: i === 0 ? INK : (S.dark ? '#2E2E2F' : '#E6E6E2')
        }));
      })(),
      xarPeriods: [['hafta', 'Hafta'], ['oy', 'Oy'], ['yil', 'Yil']].map(([k, l]) => ({
        label: l, pick: () => this.setState({ xarPeriod: k }),
        bg: S.xarPeriod === k ? INK : 'transparent', fg: S.xarPeriod === k ? BG : MUT, bd: S.xarPeriod === k ? INK : BD
      })),
      xarNetCap: (S.xarPeriod === 'hafta' ? 'HAFTA' : S.xarPeriod === 'oy' ? 'OY' : 'YIL') + ' · SOF NATIJA',
      xarNet: (net >= 0 ? '+' : '−') + money(Math.abs(net), 'UZS'),
      xarOutTxt: '−' + money(out, 'UZS'),
      xarInTxt: '+' + money(inc, 'UZS'),
      redC: red, greenC: green,
      xarCats: perCat.map(x => ({ abbr: abbr(x.c), name: x.c, amt: money(x.v, 'UZS'), w: Math.max(4, Math.round(x.v / maxCat * 100)) })),
      xarCatsEmpty: perCat.length === 0,
      xarRows: [...inP].sort((a, b) => a.days - b.days).slice(0, 10).map(e => ({
        abbr: abbr(e.cat), note: e.note, sub: e.cat + ' · ' + fmtDay(e.days),
        amt: (e.kind === 'd' ? '+' : '−') + money(e.a, 'UZS'), color: e.kind === 'd' ? green : red
      })),
      xarMicTap: () => this.setState({ voiceStage: 'listen', vText: '' }),
      xarTextVal: S.xarText,
      xarTextSet: e => this.setState({ xarText: e.target.value }),
      xarTextGo: () => { const t = this.state.xarText.trim(); if (!t) { this.toast_('Jumla yozing'); return; } this.xarPick_(t); },
      vOpen: !!S.voiceStage, vListen: S.voiceStage === 'listen', vParsing: S.voiceStage === 'parsing', vPreview: S.voiceStage === 'preview',
      vText: S.vText, vHasText: !!S.vText,
      vClose: () => { clearTimeout(this._xt); this.setState({ voiceStage: null, vText: '' }); },
      vSamples: ['Taksiga 25 ming', 'Oyligim 5 million tushdi', '50 ming oziq-ovqatga'].map(text => ({ text, pick: () => this.xarPick_(text) })),
      vWave: Array.from({ length: 21 }, (_, i) => ({ h: 10 + ((i * 53) % 37), dur: (0.55 + ((i * 29) % 40) / 100).toFixed(2) + 's', delay: '-' + (i * 0.09).toFixed(2) + 's' }))
    };
  }

  renderVals() {
    const S = this.state, P = this.props;
    const L = this.L();
    const dk = S.dark;
    const INK = dk ? '#F5F5F5' : '#111111';
    const BG = dk ? '#0F0F10' : '#FFFFFF';
    const BD = dk ? '#2E2E2F' : '#E0E0DC';
    const MUT = dk ? '#86868A' : '#A2A29E';
    const green = P.strictMono ? INK : (P.greenColor ?? (dk ? '#4CAF82' : '#2F7A54'));
    const red = P.strictMono ? INK : (P.redColor ?? (dk ? '#D2695B' : '#A94438'));
    const priv = !!P.privacyMode;
    const fmt = n => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    const money = (a, cur) => priv ? '•••' : (cur === 'USD' ? fmt(a) + ' $' : fmt(a) + ' ' + L.som);
    const sign = t => (t === 'Qarz berdim' || t === "To'lov berdim") ? 1 : -1;
    const initials = n => n.split(' ').map(w => w[0]).slice(0, 2).join('').toUpperCase();
    const bal = cid => {
      const b = { UZS: 0, USD: 0 };
      S.txs.forEach(t => { if (t.c === cid && t.st !== 'pending') b[t.cur] += sign(t.type) * t.a; });
      return b;
    };
    const balMain = b => {
      if (b.UZS === 0 && b.USD === 0) return { text: priv ? '•••' : L.zero, color: MUT, sub: L.subZero };
      const v = b.UZS !== 0 ? b.UZS : b.USD;
      const cur = b.UZS !== 0 ? 'UZS' : 'USD';
      const pos = v > 0;
      return { text: (pos ? '+' : '−') + money(Math.abs(v), cur), color: pos ? green : red, sub: pos ? L.subPos : L.subNeg };
    };

    // Home
    const q = S.search.trim().toLowerCase();
    const homeFiltered = S.clients.filter(c => !c.archived && c.name.toLowerCase().includes(q));
    const clientRows = (S.skelHome ? [] : homeFiltered.slice(0, S.homeVis)).map(c => {
      const b = balMain(bal(c.id));
      const last = [...S.txs].reverse().find(t => t.c === c.id);
      return {
        ...this.swipe_(c.id, () => this.archive_(c.id)),
        actLabel: 'Arxiv',
        tx: S.swipeId === c.id ? S.swipeDx : (S.swipeSnap === c.id ? -96 : 0),
        trans: S.swipeId === c.id ? 'none' : 'transform 0.25s ease',
        archTap: () => this.archive_(c.id),
        name: c.name, initials: initials(c.name),
        onTrust: c.onTrust !== false, oneSided: c.onTrust === false,
        sub: last ? L.last + last.date : L.noOps,
        bal: b.text, color: b.color, balSub: b.sub,
        open: () => {
          if (this._swClick) { this._swClick = false; return; }
          if (this.state.swipeSnap === c.id) { this.setState({ swipeSnap: null }); return; }
          this.setState({ clientId: c.id, tab: 'chat', codeInput: '', codeError: false, flipped: false, cMenuOpen: false, cRen: null, pProfOpen: false, opsVis: 8 });
        }
      };
    });
    let toMeUZS = 0, toMeUSD = 0, byMe = 0;
    S.clients.forEach(c => {
      const b = bal(c.id);
      if (b.UZS > 0) toMeUZS += b.UZS;
      if (b.UZS < 0) byMe += -b.UZS;
      if (b.USD > 0) toMeUSD += b.USD;
    });
    const net = toMeUZS - byMe;

    // Client detail
    const client = S.clients.find(c => c.id === S.clientId);
    const flip = !!S.flipped && !!client && client.onTrust !== false;
    const flipT = tp => flip ? (({ 'Qarz berdim': 'Qarz oldim', 'Qarz oldim': 'Qarz berdim', "To'lov oldim": "To'lov berdim", "To'lov berdim": "To'lov oldim" })[tp] || tp) : tp;
    let cName = '', cInitials = '', cBal = '', cBalColor = INK;
    let pendText = '', hasPend = false;
    let chatItems = [], opsRows = [], moreOps = false;
    if (client) {
      const b0 = bal(client.id);
      const b = balMain(flip ? { UZS: -b0.UZS, USD: -b0.USD } : b0);
      cName = flip ? 'Jasur Toshmatov' : client.name;
      cInitials = flip ? 'JT' : initials(client.name);
      cBal = L.balPfx + b.text; cBalColor = b.color;
      const pend = S.txs.filter(t => t.c === client.id && t.st === 'pending');
      hasPend = pend.length > 0;
      if (hasPend) {
        const pSum = cur => pend.filter(t => t.cur === cur).reduce((s, t) => s + sign(flipT(t.type)) * t.a, 0);
        const parts = ['UZS', 'USD'].map(cur => ({ cur, v: pSum(cur) })).filter(p => p.v !== 0)
          .map(p => (p.v > 0 ? '+' : '−') + money(Math.abs(p.v), p.cur));
        pendText = 'Kutilmoqda: ' + pend.length + ' amal' + (parts.length ? ' · ' + parts.join(' · ') : '');
      }
      const txRow = t => {
        const et = flipT(t.type);
        return {
        stLabel: t.st === 'pending' ? L.stPending : (t.st === 'unconf' ? 'Tasdiqsiz' : (t.st === 'arch' ? L.stArch : L.stOk)),
        dot: (t.st === 'pending' || t.st === 'unconf') ? (dk ? '#55555A' : '#C9C9C5') : INK,
        type: this.typeLabel(et),
        amount: (sign(et) > 0 ? '+' : '−') + money(t.a, t.cur),
        acolor: sign(et) > 0 ? green : red,
        date: t.date,
        code: t.code,
        showInput: t.st === 'pending' && (flip ? t.by === 'me' : t.by === 'them'),
        showMyCode: t.st === 'pending' && (flip ? t.by === 'them' : t.by === 'me'),
        done: t.st === 'ok' || t.st === 'arch',
        unconf: t.st === 'unconf',
        confirm: () => this.confirmTx(t.id),
        fillCode: flip ? (() => this.setState({ codeInput: t.code, codeError: false })) : (() => {}),
        fillText: flip ? 'Kod push-bildirishnomada keldi — shu yerni bosib joylashtiring' : "Kod chatdagi xabarda — uni bosib oching, kataklar o'zi to'ladi",
        openReceipt: () => this.setState({ receiptId: t.id })
        };
      };
      chatItems = (S.msgs[client.id] || []).map((m, mi) => {
        const mn = flip ? !m.mine : !!m.mine;
        if (m.k === 'voice' || m.k === 'vnote') {
          const key = client.id + ':' + mi;
          const p = (S.playing && S.playing.key === key) ? S.playing : null;
          const prog = p ? p.prog : 0;
          const isPlaying = !!(p && !p.paused);
          const checks = mn ? ((flip ? m.read !== false : m.read) ? ' ✓✓' : ' ✓') : '';
          if (m.k === 'voice') {
            const nBars = 24;
            const bars = Array.from({ length: nBars }, (_, i) => {
              const h = 4 + Math.round(Math.abs(Math.sin(i * 2.7 + mi * 3.1)) * 12);
              const filled = (i + 1) / nBars <= prog;
              const c = mn
                ? (filled ? BG : (dk ? 'rgba(15,15,16,0.35)' : 'rgba(255,255,255,0.35)'))
                : (filled ? INK : (dk ? '#55555A' : '#C9C9C5'));
              return { h, c };
            });
            const cur = Math.round(prog * m.dur);
            return {
              isVoice: true, isVnote: false, isText: false, isSys: false, isTx: false, isCode: false,
              align: mn ? 'flex-end' : 'flex-start',
              bg: mn ? INK : (dk ? '#1C1C1E' : '#F4F4F2'),
              pbg: mn ? BG : INK,
              pfg: mn ? INK : BG,
              tc: mn ? (dk ? 'rgba(15,15,16,0.5)' : 'rgba(255,255,255,0.55)') : (dk ? '#77777C' : '#A6A6A2'),
              bars, isPlaying, notPlaying: !isPlaying,
              durText: '0:' + String(p ? cur : m.dur).padStart(2, '0'),
              time: m.time, checks,
              toggle: () => this.togglePlay(key, m.dur)
            };
          }
          const rem = m.dur - Math.round(prog * m.dur);
          return {
            isVnote: true, isVoice: false, isText: false, isSys: false, isTx: false, isCode: false,
            align: mn ? 'flex-end' : 'flex-start',
            ring: 'conic-gradient(' + INK + ' ' + Math.round(prog * 360) + 'deg, ' + (dk ? '#2E2E2F' : '#E0E0DC') + ' 0)',
            vbg: dk ? '#1C1C1E' : '#F4F4F2',
            stripe: dk ? 'rgba(245,245,245,0.05)' : 'rgba(17,17,17,0.05)',
            pbg2: dk ? 'rgba(245,245,245,0.18)' : 'rgba(17,17,17,0.55)',
            pfg2: dk ? '#F5F5F5' : '#FFFFFF',
            tcv: dk ? 'rgba(245,245,245,0.4)' : 'rgba(17,17,17,0.35)',
            isPlaying, notPlaying: !isPlaying,
            durText: '0:' + String(p ? rem : m.dur).padStart(2, '0'),
            time: m.time, checks,
            toggle: () => this.togglePlay(key, m.dur)
          };
        }
        if (m.k === 'code') {
          const key = client.id + ':' + mi;
          const revealed = !!(S.revealed || {})[key];
          return {
            isCode: true, isText: false, isSys: false, isTx: false, isVoice: false, isVnote: false,
            bg: dk ? '#1C1C1E' : '#F4F4F2',
            fg: INK,
            cap: dk ? '#77777C' : '#A6A6A2',
            align: mn ? 'flex-end' : 'flex-start',
            capText: flip ? 'Kodni ikkinchi tomon kiritadi' : 'Kod pastdagi kataklarga joylashtirildi',
            hidden: !revealed, revealed,
            codeText: m.code.split('').join(' '),
            time: m.time,
            revealTap: () => this.setState({ revealed: { ...(S.revealed || {}), [key]: true }, codeInput: m.code, codeError: false })
          };
        }
        if (m.k === 'text') return {
          isText: true, isTx: false, isSys: false, isVoice: false, isVnote: false, isCode: false,
          checks: mn ? ((flip ? m.read !== false : m.read) ? ' ✓✓' : ' ✓') : '',
          align: mn ? 'flex-end' : 'flex-start',
          bg: mn ? INK : (dk ? '#1C1C1E' : '#F4F4F2'),
          fg: mn ? BG : INK,
          tc: mn ? (dk ? 'rgba(15,15,16,0.45)' : 'rgba(255,255,255,0.5)') : (dk ? '#77777C' : '#A6A6A2'),
          text: m.text, time: m.time
        };
        if (m.k === 'sys') return { isSys: true, isText: false, isTx: false, isVoice: false, isVnote: false, isCode: false, text: m.text };
        return { isTx: true, isText: false, isSys: false, isVoice: false, isVnote: false, isCode: false, ...txRow(S.txs.find(x => x.id === m.tx)) };
      });
      const opsAll = S.txs.filter(t => t.c === client.id).slice().reverse();
      moreOps = opsAll.length > S.opsVis;
      opsRows = opsAll.slice(0, S.opsVis).map(t => {
        const r = txRow(t);
        return {
          type: this.typeLabel(flipT(t.type)), date: t.date + (t.st === 'ok' ? ' · ' + L.kod + ' ' + t.code : ''),
          amount: r.amount, color: r.acolor, st: r.stLabel, dot: r.dot,
          cursor: (t.st === 'ok' || t.st === 'arch') ? 'pointer' : 'default',
          open: (t.st === 'ok' || t.st === 'arch') ? (() => this.setState({ receiptId: t.id })) : (() => {})
        };
      });
    }

    // Receipt
    let receipt = { close: () => {}, share: () => {}, change: () => {}, archive: () => {} };
    const rt = S.txs.find(x => x.id === S.receiptId);
    if (rt) {
      const rc = S.clients.find(x => x.id === rt.c);
      const meGives = rt.type === 'Qarz berdim' || rt.type === "To'lov berdim";
      receipt = {
        id: 'TR-' + (2480 + S.txs.indexOf(rt)),
        type: this.typeLabel(rt.type),
        amount: money(rt.a, rt.cur),
        from: meGives ? L.me : rc.name,
        to: meGives ? rc.name : L.me,
        date: rt.date === 'Bugun' ? '12-iyul, 2026' : rt.date + ', 2026',
        code: rt.code.split('').join(' '),
        editPending: !!rt.edit,
        editLine: rt.edit ? money(rt.a, rt.cur) + ' → ' + money(rt.edit.a, rt.cur) : '',
        corrected: !!(rt.hist && rt.hist.length),
        histRows: rt.hist || [],
        close: () => this.setState({ receiptId: null, pdfOpen: false }),
        share: () => this.setState({ pdfOpen: true }),
        change: () => {
          if (rt.edit) this.toast_("So'rov allaqachon yuborilgan");
          else this.setState({ editFormOpen: true, editA: '', editNote: rt.note || '' });
        },
        archive: () => {
          this.setState({ txs: S.txs.map(x => x.id === rt.id ? { ...x, st: 'arch' } : x), receiptId: null });
          this.toast_(L.tArch);
        }
      };
    }

    // PDF preview
    let pdf = {};
    if (rt) {
      const rc2 = S.clients.find(x => x.id === rt.c);
      const meGives2 = rt.type === 'Qarz berdim' || rt.type === "To'lov berdim";
      const myPhone = '+998 90 123 45 67';
      pdf = {
        docId: 'TR-2026-000' + (510 + S.txs.indexOf(rt)),
        fromName: meGives2 ? 'Jasur Toshmatov' : rc2.name,
        fromPhone: meGives2 ? myPhone : (rc2.phone || ''),
        toName: meGives2 ? rc2.name : 'Jasur Toshmatov',
        toPhone: meGives2 ? (rc2.phone || '') : myPhone,
        amount: money(rt.a, rt.cur),
        type: this.typeLabel(rt.type),
        dateTime: (rt.date === 'Bugun' ? '13-iyul 2026' : rt.date + ' 2026') + ' · 09:41',
        madeAt: '09:20', okAt: '09:41',
        code: rt.code.split('').join(' '),
        corrected: !!(rt.hist && rt.hist.length),
        histRows: rt.hist || []
      };
    }



    // Moliya
    const given = S.txs.filter(t => t.st !== 'pending' && t.type === 'Qarz berdim' && t.cur === 'UZS').reduce((s, t) => s + t.a, 0);
    const taken = S.txs.filter(t => t.st !== 'pending' && t.type === 'Qarz oldim' && t.cur === 'UZS').reduce((s, t) => s + t.a, 0);
    const repaid = S.txs.filter(t => t.st !== 'pending' && t.type === "To'lov oldim" && t.cur === 'UZS').reduce((s, t) => s + t.a, 0);
    const molTotals = [
      { label: L.given, value: money(given, 'UZS'), color: INK },
      { label: L.taken, value: money(taken, 'UZS'), color: INK },
      { label: L.repaid, value: money(repaid, 'UZS'), color: INK },
      { label: L.netLabel, value: (net >= 0 ? '+' : '−') + money(Math.abs(net), 'UZS'), color: net > 0 ? green : net < 0 ? red : INK }
    ];
    const barData = [['Fev', 1.1], ['Mar', 0.7], ['Apr', 1.9], ['May', 0.9], ['Iyn', 2.3], ['Iyl', 3.1]];
    const bars = barData.map(([label, v], i) => ({
      label, val: priv ? '•' : v.toFixed(1),
      h: Math.round(v / 3.1 * 80),
      bg: i === barData.length - 1 ? INK : (dk ? '#2E2E2F' : '#E6E6E2')
    }));
    const mkRem = (key, name, sub) => {
      const last = (S.remTimes || {})[key] || 0;
      const left = 10800000 - (Date.now() - last);
      const cool = !!last && left > 0;
      const hrs = Math.floor(left / 3600000);
      const mins = Math.min(59, Math.max(1, Math.ceil((left % 3600000) / 60000)));
      return {
        name, sub,
        canRemind: !cool, cooling: cool,
        coolText: cool ? 'Keyingi eslatma: ' + hrs + 's ' + mins + 'm' : '',
        remind: () => {
          const lt = (this.state.remTimes || {})[key] || 0;
          if (Date.now() - lt < 10800000) return;
          this.setState({ remTimes: { ...this.state.remTimes, [key]: Date.now() } });
          this.toast_('Eslatma yuborildi — ' + name.split(' ')[0] + ' push oladi');
        }
      };
    };
    const reminders = [
      mkRem('r1', 'Dilnoza Yusupova', money(350000, 'UZS') + ' · ' + L.due + ': 15-iyul'),
      mkRem('r2', "Qo'shni Karim", money(50000, 'UZS') + ' · ' + L.due + ': 20-iyul')
    ];

    const xarV = this.xarVals_({ INK, BG, BD, MUT, money, red, green, priv });

    // Profil
    const mkSwitch = (label, on, tap) => ({
      label, isSwitch: true, isPlain: false, value: '',
      trk: on ? INK : (dk ? '#3A3A3C' : '#D9D9D5'),
      knob: dk ? '#0F0F10' : '#FFFFFF',
      knobLeft: on ? '21px' : '3px',
      tap
    });
    const profRows = [
      { label: L.profTil, value: L.profTilVal, isPlain: true, isSwitch: false, tap: () => {} },
      { label: L.profCur, value: 'UZS', isPlain: true, isSwitch: false, tap: () => {} },
      mkSwitch('Tungi rejim', dk, () => this.setDark(!dk)),
      mkSwitch(L.profPin, S.pinOn, () => this.setState({ pinOn: !S.pinOn })),
      mkSwitch(L.profNotif, S.notifOn, () => this.setState({ notifOn: !S.notifOn })),
      { label: L.profArch, value: (S.txs.filter(t => t.st === 'arch').length || '') + '', isPlain: true, isSwitch: false, tap: () => {} }
    ];

    // Sheet
    const f = S.form;
    const types = ['Qarz berdim', 'Qarz oldim', "To'lov oldim", "To'lov berdim"].map(tp => ({
      label: this.typeLabel(tp), bg: f.type === tp ? INK : BG,
      fg: f.type === tp ? BG : INK,
      bd: f.type === tp ? INK : BD,
      pick: () => this.setState({ form: { ...f, type: tp } })
    }));
    const curs = ['UZS', 'USD'].map(cu => ({
      label: cu, bg: f.currency === cu ? INK : BG,
      fg: f.currency === cu ? BG : INK,
      pick: () => this.setState({ form: { ...f, currency: cu } })
    }));
    const shCl = S.clients.find(x => x.id === S.sheetClient);
    const shTwo = shCl ? shCl.onTrust !== false : true;
    const sheetClients = S.clients.filter(c => !c.archived).map(c => ({
      name: c.name.split(' ')[0],
      bg: S.sheetClient === c.id ? INK : BG,
      fg: S.sheetClient === c.id ? BG : INK,
      bd: S.sheetClient === c.id ? INK : BD,
      pick: () => this.setState({ sheetClient: c.id })
    }));

    // Onboarding
    const stage = S.stage;
    const ccOnb = this.ccEntry(S.onbCc);
    const ccNp = this.ccEntry(S.npCc);
    const fmtIntl = (d, dial) => dial === '+998' ? fmtPhone(d) : d.replace(/(\d{3})(?=\d)/g, '$1 ');
    const fmtPhone = d => {
      let out = d.slice(0, 2);
      if (d.length > 2) out += ' ' + d.slice(2, 5);
      if (d.length > 5) out += ' ' + d.slice(5, 7);
      if (d.length > 7) out += ' ' + d.slice(7, 9);
      return out;
    };
    const otpBoxes = [0, 1, 2, 3, 4].map(i => ({
      d: S.otpVal[i] || '',
      bd: (stage === 'otp' && i === Math.min(S.otpVal.length, 4)) ? INK : BD
    }));
    const pinDots = [0, 1, 2, 3].map(i => ({ bg: i < S.pinVal.length ? INK : 'transparent' }));

    // Notifications + second-party confirm
    const notifRows = S.notifs.map(n => ({
      title: n.title, detail: n.detail, time: n.time, unread: !!n.unread,
      isReq: n.kind === 'request', isOk: n.kind === 'confirmed', isRem: n.kind === 'reminder',
      isEdit: n.kind === 'editreq', isRej: n.kind === 'rejected',
      tap: () => {
        const notifs = S.notifs.map(x => x.id === n.id ? { ...x, unread: false } : x);
        if (n.kind === 'request') {
          const t = S.txs.find(x => x.id === n.tx);
          if (t && t.st === 'pending') this.setState({ notifs, confirmId: n.tx, cfVal: '', cfError: false });
          else this.setState({ notifs, receiptId: n.tx });
        } else if (n.kind === 'editreq') {
          const t = S.txs.find(x => x.id === n.tx);
          if (t && t.edit) this.setState({ notifs, reviewId: n.tx });
          else this.setState({ notifs, receiptId: n.tx });
        } else if (n.kind === 'confirmed' || n.kind === 'rejected') {
          this.setState({ notifs, receiptId: n.tx });
        } else {
          this.setState({ notifs, notifOpen: false, clientId: n.client || 'c2', tab: 'chat', codeInput: '', codeError: false });
        }
      }
    }));
    const cfTx = S.txs.find(x => x.id === S.confirmId);
    const cfClient = cfTx ? S.clients.find(x => x.id === cfTx.c) : null;
    const cfBoxes = [0, 1, 2, 3, 4].map(i => ({
      d: S.cfVal[i] || '',
      bd: i === Math.min(S.cfVal.length, 4) ? INK : BD
    }));
    const codeBoxes = [0, 1, 2, 3, 4].map(i => ({ d: S.codeInput[i] || '', bd: S.codeInput[i] ? INK : BD }));
    const cfTitle = cfClient ? cfClient.name + ' ' + money(cfTx.a, cfTx.cur) + " amalini tasdiqlashingizni so'rayapti" : '';
    const cfSub = cfTx ? this.typeLabel(cfTx.type) + ' · ' + cfTx.date + ' · kod push-bildirishnomada' : '';
    const cfInitials = cfClient ? initials(cfClient.name) : '';
    const rvTx = S.txs.find(x => x.id === S.reviewId);
    const rvClient = rvTx ? S.clients.find(x => x.id === rvTx.c) : null;
    const openSecond = () => {
      const t = S.txs.find(x => x.id === 't10');
      if (t && t.st === 'pending') this.setState({ pushOpen: false, notifOpen: true, confirmId: 't10', cfVal: '', cfError: false });
      else this.setState({ pushOpen: false, notifOpen: true, receiptId: 't10' });
    };

    const active = INK, idle = dk ? '#6B6B70' : '#B5B5B1';
    const noClient = !S.clientId;

    return {
      isHome: S.screen === 'home' && noClient,
      isMoliya: S.screen === 'moliya' && noClient,
      isXarajat: S.screen === 'xarajat' && noClient,
      isProfil: S.screen === 'profil' && noClient,
      netText: (net >= 0 ? '+' : '−') + money(Math.abs(net), 'UZS'),
      netColor: net > 0 ? green : net < 0 ? red : INK,
      owedToMe: money(toMeUZS, 'UZS') + (toMeUSD ? ' · ' + money(toMeUSD, 'USD') : ''),
      owedByMe: money(byMe, 'UZS'),
      search: S.search,
      onSearch: e => this.setState({ search: e.target.value, homeVis: 6 }),
      clientRows,
      hasArch: !S.skelHome && S.clients.some(c => c.archived),
      archRows: S.clients.filter(c => c.archived).map(c => ({
        ...this.swipe_('a' + c.id, () => this.restore_(c.id)),
        tx: S.swipeId === 'a' + c.id ? S.swipeDx : (S.swipeSnap === 'a' + c.id ? -96 : 0),
        trans: S.swipeId === 'a' + c.id ? 'none' : 'transform 0.25s ease',
        name: c.name, initials: initials(c.name),
        rowTap: () => {
          if (this._swClick) { this._swClick = false; return; }
          if (this.state.swipeSnap === 'a' + c.id) this.setState({ swipeSnap: null });
        },
        restore: () => this.restore_(c.id)
      })),
      skelHome: S.skelHome,
      skelRows: [{ w1: '46%', w2: '30%' }, { w1: '58%', w2: '26%' }, { w1: '40%', w2: '34%' }, { w1: '52%', w2: '24%' }, { w1: '44%', w2: '30%' }, { w1: '56%', w2: '28%' }],
      homeLoadingMore: S.homeLoadingMore,
      homeScroll: e => {
        const el = e.target;
        const st = this.state;
        if (st.skelHome || st.homeLoadingMore) return;
        const cq2 = st.search.trim().toLowerCase();
        const flt = st.clients.filter(c => !c.archived && c.name.toLowerCase().includes(cq2));
        if (flt.length <= st.homeVis) return;
        if (el.scrollTop + el.clientHeight < el.scrollHeight - 140) return;
        this.setState({ homeLoadingMore: true });
        setTimeout(() => this.setState({ homeVis: this.state.homeVis + 10, homeLoadingMore: false }), 550);
      },
      openSheetHome: () => this.setState({ npOpen: true, npName: '', npPhone: '', npType: 'on' }),
      npOpen: S.npOpen,
      npClose: () => this.setState({ npOpen: false }),
      npName: S.npName,
      onNpName: e => this.setState({ npName: e.target.value }),
      npPhoneText: fmtIntl(S.npPhone, S.npCc),
      onNpPhone: e => this.setState({ npPhone: e.target.value.replace(/\D/g, '').slice(0, ccNp.len) }),
      npCcFlag: ccNp.f, npCcDial: ccNp.d, npPh: ccNp.ph,
      npPickOn: () => this.setState({ npType: 'on' }),
      npPickInv: () => this.setState({ npType: 'inv' }),
      npOnBg: S.npType === 'on' ? INK : BG, npOnFg: S.npType === 'on' ? BG : INK, npOnBd: S.npType === 'on' ? INK : BD,
      npInvBg: S.npType === 'inv' ? INK : BG, npInvFg: S.npType === 'inv' ? BG : INK, npInvBd: S.npType === 'inv' ? INK : BD,
      npHint: S.npType === 'on' ? "Hamkor Trust'da — yozuvlar ikki tomonlama tasdiqlanadi va dalil bo'ladi" : "SMS taklif yuboriladi. Hamkor qo'shilguncha yozuvlar tasdiqsiz saqlanadi",
      npCreate: () => {
        const nm = S.npName.trim();
        if (!nm) { this.toast_('Ismni kiriting'); return; }
        if (S.npPhone.length !== ccNp.len) { this.toast_(L.tNum); return; }
        const id = 'c' + Date.now();
        const cl = { id, name: nm, phone: S.npCc + ' ' + fmtIntl(S.npPhone, S.npCc), onTrust: S.npType === 'on' };
        this.setState({ clients: [cl, ...S.clients], npOpen: false, clientId: id, tab: 'chat', flipped: false, cMenuOpen: false, cRen: null, pProfOpen: false, codeInput: '', codeError: false, opsVis: 8 });
        this.toast_(S.npType === 'on' ? "Hamkor qo'shildi" : 'Taklif SMS yuborildi');
      },
      goHome: () => this.setState({ screen: 'home', clientId: null, receiptId: null }),
      goMoliya: () => this.setState({ screen: 'moliya', clientId: null, receiptId: null }),
      goProfil: () => this.setState({ screen: 'profil', clientId: null, receiptId: null }),
      cMij: S.screen === 'home' ? active : idle,
      cMol: S.screen === 'moliya' ? active : idle,
      goXarajat: () => this.setState({ screen: 'xarajat', clientId: null, receiptId: null }),
      cXar: S.screen === 'xarajat' ? active : idle,
      ...xarV,
      cProf: S.screen === 'profil' ? active : idle,

      clientOpen: !!client,
      cName, cInitials, cBal, cBalColor,
      hasPend, pendText,
      canFlip: !!client && client.onTrust !== false,
      oneSided: !!client && client.onTrust === false,
      cOnTrust: !!client && client.onTrust !== false,
      menuOpen: S.cMenuOpen,
      menuTap: () => { if (flip) return; this.setState({ cMenuOpen: !S.cMenuOpen }); },
      menuClose: () => this.setState({ cMenuOpen: false }),
      menuRename: () => this.setState({ cMenuOpen: false, cRen: client ? client.name : '' }),
      menuArchive: () => {
        if (!client) return;
        this.setState({ clients: S.clients.map(x => x.id === client.id ? { ...x, archived: true } : x), cMenuOpen: false, clientId: null });
        this.toast_(L.tArch);
      },
      menuProfile: () => this.setState({ cMenuOpen: false, pProfOpen: true }),
      renaming: S.cRen !== null,
      notRenaming: S.cRen === null,
      showChev: !flip,
      renVal: S.cRen || '',
      onRen: e => this.setState({ cRen: e.target.value }),
      renKey: e => { if (e.key === 'Enter') this.renSave_(); },
      renSave: () => this.renSave_(),
      pProfOpen: S.pProfOpen,
      pProfClose: () => this.setState({ pProfOpen: false }),
      stopProp: e => e.stopPropagation(),
      pPhone: client ? client.phone : '',
      pStatus: client ? (client.onTrust !== false ? "Trust'da — ikki tomonlama tasdiq" : "Trust'da yo'q — yozuvlar tasdiqsiz") : '',
      pOps: client ? String(S.txs.filter(t => t.c === client.id).length) : '',
      pBal: cBal.replace(L.balPfx, ''),
      inviteTap: () => {
        if (!client || this._inv) return;
        this._inv = client.id;
        const cid = client.id;
        this.toast_('Taklif SMS yuborildi — ' + client.name.split(' ')[0] + ' kutilmoqda');
        setTimeout(() => {
          this._inv = null;
          const S2 = this.state;
          const cl2 = S2.clients.find(x => x.id === cid);
          if (!cl2 || cl2.onTrust) return;
          const msgs = { ...S2.msgs };
          msgs[cid] = [...(msgs[cid] || []), { k: 'sys', text: cl2.name.split(' ')[0] + " Trust'ga qo'shildi · endi yozuvlar ikki tomonlama tasdiqlanadi" }];
          this.setState({ clients: S2.clients.map(x => x.id === cid ? { ...x, onTrust: true } : x), msgs });
          this.toast_(cl2.name.split(' ')[0] + " Trust'ga qo'shildi");
        }, 2600);
      },
      flipped: flip,
      flipWho: flip ? client.name : '',
      flipTap: () => {
        if (!client) return;
        const nf = !S.flipped;
        this.setState({ flipped: nf });
        this.toast_(nf ? client.name.split(' ')[0] + " ko'rinishi (demo)" : "O'z ko'rinishingizga qaytdingiz");
      },
      flipBg: flip ? INK : 'transparent',
      flipFg: flip ? BG : INK,
      flipBd: flip ? INK : BD,
      back: () => this.setState({ clientId: null, flipped: false, cMenuOpen: false, cRen: null, pProfOpen: false }),
      toChat: () => this.setState({ tab: 'chat' }),
      toOps: () => {
        const cid = S.clientId;
        this._opsSeen = this._opsSeen || {};
        if (cid && !this._opsSeen[cid]) {
          this._opsSeen[cid] = true;
          this.setState({ tab: 'ops', skelOps: true });
          setTimeout(() => this.setState({ skelOps: false }), 650);
        } else this.setState({ tab: 'ops' });
      },
      skelOps: S.skelOps,
      notSkelOps: !S.skelOps,
      opsLoadingMore: S.opsLoadingMore,
      opsScroll: e => {
        const el = e.target;
        const st = this.state;
        if (st.skelOps || st.opsLoadingMore || !st.clientId) return;
        const cnt = st.txs.filter(t => t.c === st.clientId).length;
        if (cnt <= st.opsVis) return;
        if (el.scrollTop + el.clientHeight < el.scrollHeight - 120) return;
        this.setState({ opsLoadingMore: true });
        setTimeout(() => this.setState({ opsVis: this.state.opsVis + 10, opsLoadingMore: false }), 550);
      },
      isChatTab: S.tab === 'chat',
      isOpsTab: S.tab === 'ops',
      chatTabColor: S.tab === 'chat' ? INK : MUT,
      chatTabLine: S.tab === 'chat' ? INK : 'transparent',
      opsTabColor: S.tab === 'ops' ? INK : MUT,
      opsTabLine: S.tab === 'ops' ? INK : 'transparent',
      chatItems, opsRows,
      codeBoxes,
      codeInput: S.codeInput,
      onCodeInput: e => this.setState({ codeInput: e.target.value.replace(/\D/g, '').slice(0, 5), codeError: false }),
      codeError: S.codeError,
      chatInput: S.chatInput,
      onChatInput: e => this.setState({ chatInput: e.target.value }),
      sendChat: () => {
        if (!S.chatInput.trim() || !client) return;
        const msgs = { ...S.msgs };
        msgs[client.id] = [...(msgs[client.id] || []), { k: 'text', mine: !flip, text: S.chatInput.trim(), time: 'Hozir', read: false }];
        this.setState({ msgs, chatInput: '' });
        const replies = ["Xo'p bo'ladi", 'Rahmat!', "Ko'rdim, hozir javob yozaman"];
        this.replyFrom(client.id, replies[msgs[client.id].length % replies.length], 1600);
      },
      openSheetClient: () => this.setState({ sheetOpen: true, sheetMode: 'fixed', sheetClient: client.id }),
      hasText: !!S.chatInput.trim(),
      noText: !S.chatInput.trim(),
      recOn: S.recOn,
      recOff: !S.recOn,
      micTap: () => this.startRec(),
      camTap: () => this.toast_('Kamera (demo)'),
      attachTap: () => this.toast_('Fayl biriktirish (demo)'),

      receiptOpen: !!rt, receipt,
      molTotals, bars, reminders, profRows,

      sheetOpen: S.sheetOpen,
      closeSheet: () => this.setState({ sheetOpen: false }),
      sheetTitle: shTwo ? L.sheetNew : L.sheetNewBook,
      sheetClientMode: S.sheetMode !== 'fixed',
      shTwoSided: shTwo,
      sheetFixed: S.sheetMode === 'fixed' && !!shCl,
      sheetFixedName: shCl ? shCl.name : '',
      sheetFixedInitials: shCl ? initials(shCl.name) : '',
      sheetClients, types, curs,
      formAmountText: f.amount ? fmt(parseInt(f.amount, 10)) : '',
      onAmount: e => this.setState({ form: { ...f, amount: e.target.value.replace(/\D/g, '').slice(0, 12) } }),
      formNote: f.note,
      onNote: e => this.setState({ form: { ...f, note: e.target.value } }),
      sheetBtnLabel: shTwo ? L.makeCode : L.saveUnconf,
      sheetHint: shTwo ? L.hintClient : L.hintBook,
      createTx: () => this.createTx(),

      isOnbWelcome: stage === 'welcome',
      isOnbPhone: stage === 'phone',
      isOnbOtp: stage === 'otp',
      isOnbPin: stage === 'pin',
      startOnb: () => this.setState({ stage: 'phone' }),
      backToWelcome: () => this.setState({ stage: 'welcome' }),
      backToPhone: () => this.setState({ stage: 'phone', otpVal: '' }),
      backToOtp: () => this.setState({ stage: 'otp', pinVal: '' }),
      phoneText: fmtIntl(S.phone, S.onbCc),
      onPhone: e => this.setState({ phone: e.target.value.replace(/\D/g, '').slice(0, ccOnb.len) }),
      phoneNext: () => {
        if (S.phone.length === ccOnb.len) this.setState({ stage: 'otp', otpVal: '' });
        else this.toast_(L.tNum);
      },
      otpPhone: S.onbCc + ' ' + fmtIntl(S.phone, S.onbCc),
      onbFlag: ccOnb.f, onbDial: ccOnb.d, onbPh: ccOnb.ph,
      ccOpenOnb: () => this.setState({ ccOpen: 'onb', ccSearch: '' }),
      ccOpenNp: () => this.setState({ ccOpen: 'np', ccSearch: '' }),
      ccOpen: !!S.ccOpen,
      ccClose: () => this.setState({ ccOpen: null }),
      ccSearch: S.ccSearch,
      onCcSearch: e => this.setState({ ccSearch: e.target.value }),
      ccRows: this.CC.filter(c => {
        const cq = S.ccSearch.trim().toLowerCase();
        return !cq || c.n.toLowerCase().includes(cq) || c.d.includes(cq);
      }).map(c => ({
        flag: c.f, name: c.n, dial: c.d,
        sel: (S.ccOpen === 'np' ? S.npCc : S.onbCc) === c.d,
        pick: () => {
          if (this.state.ccOpen === 'np') this.setState({ npCc: c.d, npPhone: this.state.npPhone.slice(0, c.len), ccOpen: null });
          else this.setState({ onbCc: c.d, phone: this.state.phone.slice(0, c.len), ccOpen: null });
        }
      })),
      otpBoxes,
      otpKeys: this.makeKeys('otpVal'),
      otpConfirm: () => {
        if (S.otpVal.length === 5) this.setState({ stage: 'pin', pinVal: '' });
        else this.toast_(L.tEnterCode);
      },
      pinDots,
      pinKeys: this.makeKeys('pinVal'),
      logout: () => this.setState({ stage: 'welcome', phone: '', otpVal: '', pinVal: '', screen: 'home', clientId: null, receiptId: null, sheetOpen: false }),
      L,
      setUz: () => this.setState({ lang: 'uz' }),
      setRu: () => this.setState({ lang: 'ru' }),
      uzBg: S.lang === 'uz' ? '#111111' : '#FFFFFF', uzFg: S.lang === 'uz' ? '#FFFFFF' : '#111111', uzBd: S.lang === 'uz' ? '#111111' : '#E0E0DC',
      ruBg: S.lang === 'ru' ? '#111111' : '#FFFFFF', ruFg: S.lang === 'ru' ? '#FFFFFF' : '#111111', ruBd: S.lang === 'ru' ? '#111111' : '#E0E0DC',

      openNotifs: () => this.setState({ notifOpen: true }),
      closeNotifs: () => this.setState({ notifOpen: false }),
      notifOpen: S.notifOpen,
      notifRows,
      bellDot: S.notifs.some(n => n.unread),
      pushOpen: S.pushOpen,
      openPush: () => this.setState({ pushOpen: true }),
      closePush: () => this.setState({ pushOpen: false }),
      pushView: openSecond,
      pushConfirmBtn: openSecond,
      confirmOpen: !!cfTx,
      closeConfirm: () => this.setState({ confirmId: null, cfVal: '', cfError: false }),
      cfTitle, cfSub, cfInitials, cfBoxes,
      cfKeys: this.makeKeys('cfVal'),
      cfConfirm: () => this.confirmSecond(),
      cfError: S.cfError,

      editFormOpen: S.editFormOpen,
      closeEditForm: () => this.setState({ editFormOpen: false }),
      editOld: rt ? money(rt.a, rt.cur) : '',
      editOldRaw: rt ? String(rt.a) : '',
      editAText: S.editA ? fmt(parseInt(S.editA, 10)) : '',
      onEditA: e => this.setState({ editA: e.target.value.replace(/\D/g, '').slice(0, 12) }),
      editNote: S.editNote,
      onEditNote: e => this.setState({ editNote: e.target.value }),
      submitEdit: () => this.submitEdit(),
      reviewOpen: !!(rvTx && rvTx.edit),
      rv: (rvTx && rvTx.edit) ? {
        initials: initials(rvClient.name),
        title: rvClient.name + " yozuvni o'zgartirmoqchi",
        sub: this.typeLabel(rvTx.type) + ' · ' + rvTx.date + ' · TR-' + (2480 + S.txs.indexOf(rvTx)),
        oldAmt: money(rvTx.a, rvTx.cur),
        newAmt: money(rvTx.edit.a, rvTx.cur),
        hasNote: !!(rvTx.edit.note && rvTx.edit.note !== (rvTx.note || '')),
        newNote: rvTx.edit.note || ''
      } : {},
      approveEdit: () => this.approveEdit(),
      rejectEdit: () => this.rejectEdit(),
      closeReview: () => this.setState({ reviewId: null }),

      pdfOpen: !!(S.pdfOpen && rt),
      pdf,
      closePdf: () => this.setState({ pdfOpen: false }),
      pdfDownload: () => this.toast_('PDF yuklab olinmoqda…'),
      pdfShare: () => this.toast_('Ulashish oynasi ochildi (demo)'),

      toastOpen: !!S.toast,
      toast: S.toast
    };
  }
}
