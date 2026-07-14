import React, { useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, ActivityIndicator, Alert, TextInput,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter, useLocalSearchParams, useFocusEffect } from 'expo-router';
import { useAuth } from '../../src/auth';
import { useI18n } from '../../src/i18n';
import { Button, Card, Badge } from '../../src/ui';
import { colors, spacing, radius } from '../../src/theme';
import { formatAmount, formatPhone } from '../../src/format';

const statusMeta = (status) => ({
  pending: { color: colors.amber, bg: colors.amberBg },
  active: { color: colors.primary, bg: colors.primaryLight },
  paid: { color: colors.green, bg: colors.greenBg },
  cancelled: { color: colors.textMuted, bg: colors.border },
  disputed: { color: colors.red, bg: colors.redBg },
}[status] || { color: colors.textMuted, bg: colors.border });

export default function DebtDetail() {
  const { token, user, api } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { id } = useLocalSearchParams();

  const [debt, setDebt] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [payAmount, setPayAmount] = useState('');

  const load = useCallback(async () => {
    try {
      const d = await api.getDebt(token, id);
      setDebt(d);
    } catch (e) { setErr(e.message); }
    setLoading(false);
  }, [id, token]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const act = async (fn) => {
    setBusy(true); setErr('');
    try { await fn(); await load(); }
    catch (e) { setErr(e.message); Alert.alert(t('error'), e.message); }
    setBusy(false);
  };

  if (loading) return <View style={st.center}><ActivityIndicator color={colors.primary} size="large" /></View>;
  if (!debt) return <View style={st.center}><Text>{err || t('error')}</Text></View>;

  const lender = debt.lender_id === user?.id;
  const meta = statusMeta(debt.status);
  const paid = (debt.payments || []).reduce((s, p) => s + Number(p.amount), 0);
  const remaining = Number(debt.amount) - paid;
  const canConfirm = debt.status === 'pending' && debt.created_by !== user?.id;
  const canPay = debt.status === 'active';
  const canCancel = ['pending', 'active'].includes(debt.status);

  const submitPay = () => {
    const amt = Number(String(payAmount).replace(/\s/g, ''));
    if (!amt || amt <= 0) return;
    act(async () => { await api.addPayment(token, id, amt); setPayAmount(''); });
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <View style={[st.header, { paddingTop: insets.top + 8 }]}>
        <TouchableOpacity onPress={() => router.back()}><Text style={st.back}>‹</Text></TouchableOpacity>
        <Text style={st.hTitle}>{formatPhone(debt.counterparty_phone)}</Text>
        <View style={{ width: 30 }} />
      </View>

      <ScrollView contentContainerStyle={{ padding: spacing.md, paddingBottom: 40 }}>
        <Card style={{ alignItems: 'center', paddingVertical: spacing.lg }}>
          <Badge text={t(debt.status)} color={meta.color} bg={meta.bg} />
          <Text style={[st.bigAmount, { color: lender ? colors.green : colors.red }]}>
            {lender ? '+' : '−'}{formatAmount(debt.amount)}
          </Text>
          <Text style={st.sum}>{debt.currency || 'UZS'} {t('sum')}</Text>
          <Text style={st.role}>{lender ? t('theyOweMe') : t('iOwe')}</Text>
        </Card>

        {(paid > 0) && (
          <Card style={{ marginTop: spacing.md, flexDirection: 'row', justifyContent: 'space-between' }}>
            <View><Text style={st.k}>{t('paidSoFar')}</Text><Text style={[st.v, { color: colors.green }]}>{formatAmount(paid)}</Text></View>
            <View><Text style={st.k}>{t('remaining')}</Text><Text style={[st.v, { color: colors.red }]}>{formatAmount(remaining)}</Text></View>
          </Card>
        )}

        {debt.note ? (
          <Card style={{ marginTop: spacing.md }}>
            <Text style={st.k}>{t('note')}</Text>
            <Text style={st.noteText}>{debt.note}</Text>
          </Card>
        ) : null}

        {debt.due_date ? (
          <Card style={{ marginTop: spacing.md }}>
            <Text style={st.k}>{t('dueOn')}</Text>
            <Text style={st.noteText}>{debt.due_date}</Text>
          </Card>
        ) : null}

        {(debt.payments && debt.payments.length > 0) && (
          <Card style={{ marginTop: spacing.md }}>
            <Text style={[st.k, { marginBottom: 8 }]}>{t('payments')}</Text>
            {debt.payments.map((p) => (
              <View key={p.id} style={st.payRow}>
                <Text style={st.payDate}>{(p.created_at || '').slice(0, 10)}</Text>
                <Text style={st.payAmt}>{formatAmount(p.amount)}</Text>
              </View>
            ))}
          </Card>
        )}

        {err ? <Text style={st.err}>{err}</Text> : null}

        <View style={{ marginTop: spacing.lg, gap: spacing.sm }}>
          {canConfirm && <Button title={t('confirm')} loading={busy} onPress={() => act(() => api.confirmDebt(token, id))} />}
          {canPay && (
            <Card style={{ gap: spacing.sm }}>
              <Text style={st.k}>{t('addPayment')}</Text>
              <TextInput style={st.payInput} placeholder="100 000" keyboardType="number-pad"
                value={payAmount} onChangeText={setPayAmount} placeholderTextColor={colors.textMuted} />
              <Button title={t('addPayment')} loading={busy} onPress={submitPay} />
            </Card>
          )}
          {canCancel && <Button title={t('cancel')} variant="danger" loading={busy} onPress={() =>
            Alert.alert(t('cancel'), '', [{ text: t('close') }, { text: t('cancel'), style: 'destructive', onPress: () => act(() => api.cancelDebt(token, id)) }])
          } />}
        </View>
      </ScrollView>
    </View>
  );
}

const st = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: colors.bg },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.md, paddingBottom: spacing.sm, backgroundColor: colors.white, borderBottomWidth: 1, borderBottomColor: colors.border },
  back: { color: colors.primary, fontSize: 30, fontWeight: '400', width: 30 },
  hTitle: { fontSize: 18, fontWeight: '800', color: colors.text },
  bigAmount: { fontSize: 36, fontWeight: '800', marginTop: spacing.md },
  sum: { fontSize: 13, color: colors.textMuted },
  role: { fontSize: 14, color: colors.textMuted, marginTop: 8, fontWeight: '600' },
  k: { fontSize: 13, fontWeight: '600', color: colors.textMuted },
  v: { fontSize: 18, fontWeight: '800', marginTop: 2 },
  noteText: { fontSize: 15, color: colors.text, marginTop: 4 },
  payRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 8, borderTopWidth: 1, borderTopColor: colors.border },
  payDate: { color: colors.textMuted },
  payAmt: { fontWeight: '700', color: colors.green },
  payInput: { height: 50, borderWidth: 1.5, borderColor: colors.border, borderRadius: radius.md, paddingHorizontal: spacing.md, fontSize: 16, color: colors.text, backgroundColor: colors.white },
  err: { color: colors.red, marginTop: spacing.md, fontWeight: '600' },
});
