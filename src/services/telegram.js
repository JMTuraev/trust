// Telegram Bot API — yordam chati ko'prigi (support -> admin Telegram).
// Token FAQAT env'da (SUPPORT_TG_BOT_TOKEN); yo'q bo'lsa hammasi jim o'chiq (fail-soft).
import { config } from '../config.js';

const api = (method) => `https://api.telegram.org/bot${config.support.tgToken}/${method}`;

export function tgEnabled() {
  return !!config.support.tgToken;
}

/** Xabar yuborish. Muvaffaqiyatda Telegram message obyektini qaytaradi (message_id kerak). */
export async function tgSend(chatId, text) {
  if (!tgEnabled() || !chatId) return null;
  try {
    const r = await fetch(api('sendMessage'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
    const d = await r.json();
    if (!d?.ok) {
      console.error('tgSend xato:', d?.description || r.status);
      return null;
    }
    return d.result;
  } catch (e) {
    console.error('tgSend:', e.message);
    return null;
  }
}

/** Webhook'ni o'rnatish — har server startida (idempotent). */
export async function tgSetWebhook() {
  if (!tgEnabled()) {
    console.warn("Support chat: SUPPORT_TG_BOT_TOKEN yo'q — Telegram ko'prigi o'chiq");
    return;
  }
  try {
    const url = `${config.support.publicUrl}/api/support/telegram-webhook`;
    const r = await fetch(api('setWebhook'), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        url,
        secret_token: config.support.webhookSecret || undefined,
        allowed_updates: ['message'],
      }),
    });
    const d = await r.json();
    console.log(d?.ok ? `Telegram webhook o'rnatildi: ${url}` : `Telegram webhook xato: ${d?.description}`);
  } catch (e) {
    console.error('tgSetWebhook:', e.message);
  }
}
