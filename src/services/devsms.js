import { config } from '../config.js';

// devsms.uz orqali universal OTP SMS yuborish (Eskiz tasdiqlagan shablon)
// Shablon: "MyService tizimi: {service_name} xizmatiga kirish uchun tasdiqlash kodi: {otp_code}"
export async function sendOtpSms(phone, otpCode) {
  const res = await fetch(`${config.devsms.baseUrl}/send_sms.php`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.devsms.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      phone,
      type: 'universal_otp',
      template_type: config.devsms.templateType,
      service_name: config.devsms.serviceName,
      otp_code: otpCode,
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.success) {
    throw new Error(data.error || `DevSMS xatosi (HTTP ${res.status})`);
  }
  return data.data;
}

export async function getBalance() {
  const res = await fetch(`${config.devsms.baseUrl}/get_balance.php`, {
    headers: { Authorization: `Bearer ${config.devsms.token}` },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.success) {
    throw new Error(data.error || `DevSMS xatosi (HTTP ${res.status})`);
  }
  return data.data;
}
