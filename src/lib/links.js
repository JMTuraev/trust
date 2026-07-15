// Bog'lanish (link) yordamchilari: status o'tishlari + audit log.
// Link = partners qatori (sotuvchi <-> mijoz raqami), statuslar: pending/accepted/rejected.
import { supabaseAdmin } from './supabase.js';

/** Audit: har bir status o'zgarishi (changed_by null = tizim/migratsiya) */
export async function logLinkEvent(partnerId, fromStatus, toStatus, changedBy) {
  await supabaseAdmin.from('link_events').insert({
    partner_id: partnerId,
    from_status: fromStatus ?? null,
    to_status: toStatus,
    changed_by: changedBy ?? null,
  });
}

/** Statusni o'zgartirish + audit. Yangilangan qatorni qaytaradi. */
export async function setLinkStatus(partner, toStatus, changedBy) {
  const { data, error } = await supabaseAdmin
    .from('partners')
    .update({
      link_status: toStatus,
      status_changed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', partner.id)
    .select()
    .single();
  if (error) throw new Error(error.message);
  await logLinkEvent(partner.id, partner.link_status, toStatus, changedBy);
  return data;
}

/** Foydalanuvchining mijozga ko'rinadigan nomi: ism + telefon */
export function displayName(profile) {
  const name = (profile?.full_name || '').trim();
  const phone = profile?.phone ? `+${profile.phone}` : '';
  if (name && phone) return `${name} (${phone})`;
  return name || phone || 'Foydalanuvchi';
}

/** Bildirishnoma sozlamasi yoqiqmi (op_new/rem shu bilan boshqariladi) */
export async function notifEnabled(userId) {
  if (!userId) return false;
  const { data } = await supabaseAdmin
    .from('profiles')
    .select('notif_enabled')
    .eq('id', userId)
    .maybeSingle();
  return data?.notif_enabled !== false;
}
