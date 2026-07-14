import React, { useState } from 'react';
import {
  View, Text, StyleSheet, KeyboardAvoidingView, Platform, TouchableOpacity, ScrollView,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Button, Field } from '../src/ui';
import { useAuth } from '../src/auth';
import { useI18n } from '../src/i18n';
import { colors, spacing, radius } from '../src/theme';
import { formatPhone } from '../src/format';

function normalize(input) {
  let d = String(input).replace(/\D/g, '');
  if (d.startsWith('998')) return d;
  if (d.length === 9) return '998' + d;      // 901234567
  return d;
}

export default function Login() {
  const { signIn, api } = useAuth();
  const { t, lang, changeLang } = useI18n();
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const [step, setStep] = useState('phone'); // phone | code
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState('');

  const send = async () => {
    setErr('');
    const p = normalize(phone);
    if (p.length < 9) { setErr(t('error')); return; }
    setLoading(true);
    try {
      await api.sendOtp('+' + p);
      setStep('code');
    } catch (e) { setErr(e.message); }
    setLoading(false);
  };

  const verify = async () => {
    setErr('');
    setLoading(true);
    try {
      const p = normalize(phone);
      const s = await api.verifyOtp('+' + p, code.trim());
      await signIn(s.access_token, s.user);
      router.replace('/(tabs)');
    } catch (e) { setErr(e.message); }
    setLoading(false);
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={[st.wrap, { paddingTop: insets.top + 40 }]} keyboardShouldPersistTaps="handled">
        <View style={st.langRow}>
          {['uz', 'ru'].map((l) => (
            <TouchableOpacity key={l} onPress={() => changeLang(l)}
              style={[st.langBtn, lang === l && st.langBtnActive]}>
              <Text style={[st.langText, lang === l && st.langTextActive]}>{l.toUpperCase()}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <View style={st.logo}><Text style={st.logoText}>OB</Text></View>
        <Text style={st.title}>{t('appName')}</Text>
        <Text style={st.tagline}>{t('tagline')}</Text>

        <View style={{ height: spacing.xl }} />

        {step === 'phone' ? (
          <>
            <Field
              label={t('phone')}
              placeholder={t('phonePlaceholder')}
              keyboardType="phone-pad"
              value={phone}
              onChangeText={setPhone}
              autoFocus
            />
            {err ? <Text style={st.err}>{err}</Text> : null}
            <Button title={t('sendCode')} onPress={send} loading={loading} />
          </>
        ) : (
          <>
            <Text style={st.sent}>{t('codeSentTo')} {formatPhone(normalize(phone))}</Text>
            <Field
              label={t('enterCode')}
              placeholder="••••••"
              keyboardType="number-pad"
              value={code}
              onChangeText={setCode}
              maxLength={6}
              autoFocus
            />
            {err ? <Text style={st.err}>{err}</Text> : null}
            <Button title={t('verify')} onPress={verify} loading={loading} />
            <View style={{ height: spacing.sm }} />
            <Button title={t('changeNumber')} variant="ghost" onPress={() => { setStep('phone'); setCode(''); setErr(''); }} />
          </>
        )}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const st = StyleSheet.create({
  wrap: { paddingHorizontal: spacing.lg, paddingBottom: spacing.xl, flexGrow: 1 },
  langRow: { flexDirection: 'row', justifyContent: 'flex-end', gap: 8 },
  langBtn: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: radius.sm, borderWidth: 1, borderColor: colors.border },
  langBtnActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  langText: { fontWeight: '700', color: colors.textMuted, fontSize: 13 },
  langTextActive: { color: colors.white },
  logo: { width: 72, height: 72, borderRadius: 20, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center', alignSelf: 'center', marginTop: spacing.lg },
  logoText: { color: colors.white, fontSize: 28, fontWeight: '800' },
  title: { fontSize: 28, fontWeight: '800', color: colors.text, textAlign: 'center', marginTop: spacing.md },
  tagline: { fontSize: 15, color: colors.textMuted, textAlign: 'center', marginTop: 6 },
  sent: { fontSize: 14, color: colors.textMuted, marginBottom: spacing.md },
  err: { color: colors.red, marginBottom: spacing.sm, fontWeight: '600' },
});
