import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

const dict = {
  uz: {
    appName: 'Oldi-Berdi',
    tagline: 'Qarzlaringizni ishonch bilan yuriting',
    // login
    phone: 'Telefon raqam',
    phonePlaceholder: '90 123 45 67',
    sendCode: 'Kod yuborish',
    enterCode: 'Tasdiqlash kodi',
    codeSentTo: 'Kod yuborildi:',
    verify: 'Tasdiqlash',
    resend: 'Qayta yuborish',
    changeNumber: 'Raqamni o‘zgartirish',
    // tabs
    debts: 'Qarzlar',
    profile: 'Profil',
    // debts list
    theyOweMe: 'Menga qarzdor',
    iOwe: 'Men qarzdorman',
    totalOut: 'Berilgan',
    totalIn: 'Olingan',
    noDebts: 'Hozircha qarz yo‘q',
    addDebt: 'Qarz qo‘shish',
    // add debt
    newDebt: 'Yangi qarz',
    iLent: 'Men berdim',
    iBorrowed: 'Men oldim',
    counterpartyPhone: 'Ikkinchi taraf telefoni',
    amount: 'Summa',
    note: 'Izoh (ixtiyoriy)',
    dueDate: 'Muddat (ixtiyoriy)',
    save: 'Saqlash',
    // detail
    status: 'Holat',
    pending: 'Tasdiq kutilmoqda',
    active: 'Faol',
    paid: 'To‘langan',
    cancelled: 'Bekor qilingan',
    disputed: 'Nizoli',
    confirm: 'Tasdiqlash',
    cancel: 'Bekor qilish',
    addPayment: 'To‘lov kiritish',
    payments: 'To‘lovlar',
    paidSoFar: 'To‘langan',
    remaining: 'Qoldiq',
    // profile
    fullName: 'To‘liq ism',
    language: 'Til',
    logout: 'Chiqish',
    // common
    loading: 'Yuklanmoqda…',
    error: 'Xatolik',
    retry: 'Qayta urinish',
    close: 'Yopish',
    sum: 'so‘m',
    dueOn: 'Muddat:',
    createdBy: 'Yaratdi',
    you: 'Siz',
  },
  ru: {
    appName: 'Oldi-Berdi',
    tagline: 'Ведите долги с доверием',
    phone: 'Номер телефона',
    phonePlaceholder: '90 123 45 67',
    sendCode: 'Отправить код',
    enterCode: 'Код подтверждения',
    codeSentTo: 'Код отправлен:',
    verify: 'Подтвердить',
    resend: 'Отправить снова',
    changeNumber: 'Изменить номер',
    debts: 'Долги',
    profile: 'Профиль',
    theyOweMe: 'Мне должны',
    iOwe: 'Я должен',
    totalOut: 'Выдано',
    totalIn: 'Получено',
    noDebts: 'Пока нет долгов',
    addDebt: 'Добавить долг',
    newDebt: 'Новый долг',
    iLent: 'Я дал',
    iBorrowed: 'Я взял',
    counterpartyPhone: 'Телефон второй стороны',
    amount: 'Сумма',
    note: 'Заметка (необязательно)',
    dueDate: 'Срок (необязательно)',
    save: 'Сохранить',
    status: 'Статус',
    pending: 'Ожидает подтверждения',
    active: 'Активный',
    paid: 'Оплачено',
    cancelled: 'Отменён',
    disputed: 'Спорный',
    confirm: 'Подтвердить',
    cancel: 'Отменить',
    addPayment: 'Внести платёж',
    payments: 'Платежи',
    paidSoFar: 'Оплачено',
    remaining: 'Остаток',
    fullName: 'Полное имя',
    language: 'Язык',
    logout: 'Выйти',
    loading: 'Загрузка…',
    error: 'Ошибка',
    retry: 'Повторить',
    close: 'Закрыть',
    sum: 'сум',
    dueOn: 'Срок:',
    createdBy: 'Создал',
    you: 'Вы',
  },
};

const I18nContext = createContext(null);

export function I18nProvider({ children }) {
  const [lang, setLang] = useState('uz');
  useEffect(() => {
    AsyncStorage.getItem('lang').then((v) => v && setLang(v));
  }, []);
  const changeLang = async (l) => {
    setLang(l);
    await AsyncStorage.setItem('lang', l);
  };
  const t = (key) => dict[lang][key] ?? key;
  return (
    <I18nContext.Provider value={{ lang, changeLang, t }}>
      {children}
    </I18nContext.Provider>
  );
}

export const useI18n = () => useContext(I18nContext);
