import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, KeyboardAvoidingView, Platform,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useAuth } from '../../src/auth';
import { useI18n } from '../../src/i18n';
import { Button, Field } from '../../src/ui';
import { colors, spacing, radius } from '../../src/theme';

function normalizePhone(input) {
  let d = String(input).replace(/\D/g, '');
  if (d.length === 9) return '998' + d;
  return d;
}

export default function NewDebt() {
  const { token, api } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const [direction, setDirection] = useState('lent'); // lent | borrowed
  const [phone, setPhone] = useState('');
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState('');

  const save = async () => {
    setErr('');
    const p = normalizePhone(phone);
    const amt = Number(String(amount).replace(/\s/g, ''));
    if (p.length < 9) { setErr(t('counterpartyPhone')); return; }
    if (!amt || amt <= 0) { setErr(t('amount')); return; }
    setLoading(true);
    try {
      await api.createDebt(token, {
        direction,
        counterparty_phone: '+' + p,
        amount: amt,
        currency: 'UZS',
        note: note || null,
        due_date: dueDate || null,
      });
      router.back();
    } catch (e) { setErr(e.message); }
    setLoading(false);
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <View style={[st.header, { paddingTop: insets.top + 8 }]}>
        <TouchableOpacity onPress={() => router.back()}><Text style={st.back}>‹ {t('close')}</Text></TouchableOpacity>
        <Text style={st.title}>{t('newDebt')}</Text>
        <View style={{ width: 60 }} />
      </View>
      <ScrollView contentContainerStyle={{ padding: spacing.md }} keyboardShouldPersistTaps="handled">
        <View style={st.toggle}>
          <TouchableOpacity onPress={() => setDirection('lent')} style={[st.toggleBtn, direction === 'lent' && { backgroundColor: colors.green }]}>
            <Text style={[st.toggleText, direction === 'lent' && st.toggleTextActive]}>{t('iLent')}</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => setDirection('borrowed')} style={[st.toggleBtn, direction === 'borrowed' && { backgroundColor: colors.red }]}>
            <Text style={[st.toggleText, direction === 'borrowed' && st.toggleTextActive]}>{t('iBorrowed')}</Text>
          </TouchableOpacity>
        </View>

        <Field label={t('counterpartyPhone')} placeholder="90 123 45 67" keyboardType="phone-pad" value={phone} onChangeText={setPhone} />
        <Field label={t('amount')} placeholder="500 000" keyboardType="number-pad" value={amount} onChangeText={setAmount} />
        <Field label={t('note')} placeholder="..." value={note} onChangeText={setNote} />
        <Field label={t('dueDate') + ' (YYYY-MM-DD)'} placeholder="2026-08-01" value={dueDate} onChangeText={setDueDate} />

        {err ? <Text style={st.err}>{err}</Text> : null}
        <Button title={t('save')} onPress={save} loading={loading} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const st = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.md, paddingBottom: spacing.sm, backgroundColor: colors.white, borderBottomWidth: 1, borderBottomColor: colors.border },
  back: { color: colors.primary, fontSize: 16, fontWeight: '600', width: 90 },
  title: { fontSize: 18, fontWeight: '800', color: colors.text },
  toggle: { flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.lg },
  toggleBtn: { flex: 1, height: 52, borderRadius: radius.md, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.bg, borderWidth: 1, borderColor: colors.border },
  toggleText: { fontWeight: '700', color: colors.textMuted },
  toggleTextActive: { color: colors.white },
  err: { color: colors.red, marginBottom: spacing.sm, fontWeight: '600' },
});
