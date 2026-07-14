import Constants from 'expo-constants';

// API manzili. app.json -> extra.apiUrl da o'zgartiring,
// yoki EXPO_PUBLIC_API_URL muhit o'zgaruvchisi orqali.
export const API_URL =
  process.env.EXPO_PUBLIC_API_URL ||
  Constants.expoConfig?.extra?.apiUrl ||
  'http://localhost:3000';

async function request(path, { method = 'GET', body, token } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  let res;
  try {
    res = await fetch(`${API_URL}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    throw new Error('Serverga ulanib bo‘lmadi. Internet va API manzilini tekshiring.');
  }
  let data = {};
  try {
    data = await res.json();
  } catch {}
  if (!res.ok || data.success === false) {
    throw new Error(data.error || `Xatolik (${res.status})`);
  }
  return data.data ?? data;
}

export const api = {
  sendOtp: (phone) => request('/api/auth/send-otp', { method: 'POST', body: { phone } }),
  verifyOtp: (phone, code) =>
    request('/api/auth/verify-otp', { method: 'POST', body: { phone, code } }),
  getProfile: (token) => request('/api/profile/me', { token }),
  updateProfile: (token, patch) =>
    request('/api/profile/me', { method: 'PUT', body: patch, token }),
  listDebts: (token, query = '') => request(`/api/debts${query}`, { token }),
  getDebt: (token, id) => request(`/api/debts/${id}`, { token }),
  createDebt: (token, debt) =>
    request('/api/debts', { method: 'POST', body: debt, token }),
  confirmDebt: (token, id) =>
    request(`/api/debts/${id}/confirm`, { method: 'POST', token }),
  cancelDebt: (token, id) =>
    request(`/api/debts/${id}/cancel`, { method: 'POST', token }),
  addPayment: (token, id, amount, note) =>
    request(`/api/debts/${id}/payments`, { method: 'POST', body: { amount, note }, token }),
};
