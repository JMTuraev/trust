import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { useAuth } from '../../src/auth';
import { useI18n } from '../../src/i18n';
import { Button, Field, Card } from '../../src/ui';
import { colors, spacing, radius } from '../../src/theme';
import { formatPhone } from '../../src/format';

export default function Profile() {
  const { token, user, api, signOut } = useAuth();
  const { t, lang, changeLang } = useI18n();
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    api.getProfile(token).then((p) => setName(p?.full_name || '')).catch(() => {});
  }, [token]);

  const save = async () => {
    setSaving(true); setMsg('');
    try { await api.updateProfile(token, { full_name: name }); setMsg('✓'); }
    catch (e) { Alert.alert(t('error'), e.message); }
    setSaving(false);
  };

  const doLogout = async () => {
    await signOut();
    router.replace('/login');
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <View style={[st.header, { paddingTop: insets.top + 12 }]}>
        <Text style={st.hTitle}>{t('profile')}</Text>
      </View>
      <ScrollView contentContainerStyle={{ padding: spacing.md }}>
        <Card style={{ alignItems: 'center', paddingVertical: spacing.lg }}>
          <View style={st.avatar}><Text style={st.avatarText}>{(name || 'U')[0].toUpperCase()}</Text></View>
          <Text style={st.phone}>{formatPhone(user?.phone)}</Text>
        </Card>

        <View style={{ height: spacing.lg }} />
        <Field label={t('fullName')} value={name} onChangeText={setName} placeholder="..." />
        <Button title={t('save') + (msg ? '  ' + msg : '')} onPress={save} loading={saving} />

        <View style={{ height: spacing.lg }} />
        <Text style={st.k}>{t('language')}</Text>
        <View style={st.langRow}>
          {['uz', 'ru'].map((l) => (
            <TouchableOpacity key={l} onPress={() => changeLang(l)} style={[st.langBtn, lang === l && st.langBtnActive]}>
              <Text style={[st.langText, lang === l && st.langTextActive]}>{l === 'uz' ? "O'zbekcha" : 'Русский'}</Text>
            </TouchableOpacity>
          ))}
        </View>

        <View style={{ height: spacing.xl }} />
        <Button title={t('logout')} variant="danger" onPress={doLogout} />
      </ScrollView>
    </View>
  );
}

const st = StyleSheet.create({
  header: { paddingHorizontal: spacing.md, paddingBottom: spacing.md, backgroundColor: colors.white, borderBottomWidth: 1, borderBottomColor: colors.border },
  hTitle: { fontSize: 24, fontWeight: '800', color: colors.text },
  avatar: { width: 80, height: 80, borderRadius: 40, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center' },
  avatarText: { color: colors.white, fontSize: 32, fontWeight: '800' },
  phone: { fontSize: 17, fontWeight: '700', color: colors.text, marginTop: spacing.md },
  k: { fontSize: 13, fontWeight: '600', color: colors.textMuted, marginBottom: 8 },
  langRow: { flexDirection: 'row', gap: spacing.sm },
  langBtn: { flex: 1, height: 50, borderRadius: radius.md, alignItems: 'center', justifyContent: 'center', borderWidth: 1.5, borderColor: colors.border, backgroundColor: colors.white },
  langBtnActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  langText: { fontWeight: '700', color: colors.textMuted },
  langTextActive: { color: colors.white },
});
