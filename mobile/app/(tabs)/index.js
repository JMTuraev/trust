import React, { useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, FlatList, RefreshControl, TouchableOpacity, ActivityIndicator,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter, useFocusEffect } from 'expo-router';
import { useAuth } from '../../src/auth';
import { useI18n } from '../../src/i18n';
import { colors, spacing, radius } from '../../src/theme';
import { formatAmount, formatPhone } from '../../src/format';
import { Card, Badge } from '../../src/ui';

const statusMeta = (status) => ({
  pending: { color: colors.amber, bg: colors.amberBg },
  active: { color: colors.primary, bg: colors.primaryLight },
  paid: { color: colors.green, bg: colors.greenBg },
  cancelled: { color: colors.textMuted, bg: colors.border },
  disputed: { color: colors.red, bg: colors.redBg },
}[status] || { color: colors.textMuted, bg: colors.border });

export default function DebtsList() {
  const { token, user, api } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const [debts, setDebts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [err, setErr] = useState('');
  const [tab, setTab] = useState('all'); // all | lender | borrower

  const load = useCallback(async () => {
    setErr('');
    try {
      const rows = await api.listDebts(token);
      setDebts(Array.isArray(rows) ? rows : []);
    } catch (e) { setErr(e.message); }
    setLoading(false);
    setRefreshing(false);
  }, [token]);

  useFocusEffect(useCallback(() => { load(); }, [load]));

  const isLender = (d) => d.lender_id === user?.id;
  const filtered = debts.filter((d) => {
    if (tab === 'lender') return isLender(d);
    if (tab === 'borrower') return d.borrower_id === user?.id;
    return true;
  });

  const totalOut = debts.filter(isLender).filter((d) => ['pending','active'].includes(d.status))
    .reduce((s, d) => s + Number(d.amount), 0);
  const totalIn = debts.filter((d) => d.borrower_id === user?.id).filter((d) => ['pending','active'].includes(d.status))
    .reduce((s, d) => s + Number(d.amount), 0);

  const renderItem = ({ item }) => {
    const lender = isLender(item);
    const meta = statusMeta(item.status);
    return (
      <Card style={st.debtCard} onPress={() => router.push(`/debt/${item.id}`)}>
        <View style={{ flex: 1 }}>
          <Text style={st.debtPhone}>{formatPhone(item.counterparty_phone)}</Text>
          {item.note ? <Text style={st.debtNote} numberOfLines={1}>{item.note}</Text> : null}
          <View style={{ marginTop: 6 }}>
            <Badge text={t(item.status)} color={meta.color} bg={meta.bg} />
          </View>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <Text style={[st.debtAmount, { color: lender ? colors.green : colors.red }]}>
            {lender ? '+' : '−'}{formatAmount(item.amount)}
          </Text>
          <Text style={st.sum}>{item.currency || 'UZS'}</Text>
        </View>
      </Card>
    );
  };

  return (
    <View style={{ flex: 1, backgroundColor: colors.bg }}>
      <View style={[st.header, { paddingTop: insets.top + 12 }]}>
        <Text style={st.hTitle}>{t('debts')}</Text>
        <View style={st.summaryRow}>
          <View style={[st.summaryBox, { backgroundColor: colors.greenBg }]}>
            <Text style={st.summaryLabel}>{t('theyOweMe')}</Text>
            <Text style={[st.summaryVal, { color: colors.green }]}>{formatAmount(totalOut)}</Text>
          </View>
          <View style={[st.summaryBox, { backgroundColor: colors.redBg }]}>
            <Text style={st.summaryLabel}>{t('iOwe')}</Text>
            <Text style={[st.summaryVal, { color: colors.red }]}>{formatAmount(totalIn)}</Text>
          </View>
        </View>
        <View style={st.tabs}>
          {[['all', t('debts')], ['lender', t('theyOweMe')], ['borrower', t('iOwe')]].map(([k, label]) => (
            <TouchableOpacity key={k} onPress={() => setTab(k)} style={[st.tab, tab === k && st.tabActive]}>
              <Text style={[st.tabText, tab === k && st.tabTextActive]}>{label}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {loading ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={colors.primary} size="large" />
      ) : (
        <FlatList
          data={filtered}
          keyExtractor={(d) => d.id}
          renderItem={renderItem}
          contentContainerStyle={{ padding: spacing.md, paddingBottom: 100 }}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={() => { setRefreshing(true); load(); }} />}
          ListEmptyComponent={
            <View style={st.empty}>
              <Text style={{ fontSize: 40 }}>🪙</Text>
              <Text style={st.emptyText}>{err || t('noDebts')}</Text>
            </View>
          }
        />
      )}

      <TouchableOpacity style={[st.fab, { bottom: 24 }]} onPress={() => router.push('/debt/new')} activeOpacity={0.9}>
        <Text style={st.fabText}>＋</Text>
      </TouchableOpacity>
    </View>
  );
}

const st = StyleSheet.create({
  header: { paddingHorizontal: spacing.md, paddingBottom: spacing.md, backgroundColor: colors.white, borderBottomWidth: 1, borderBottomColor: colors.border },
  hTitle: { fontSize: 24, fontWeight: '800', color: colors.text, marginBottom: spacing.md },
  summaryRow: { flexDirection: 'row', gap: spacing.sm },
  summaryBox: { flex: 1, borderRadius: radius.md, padding: spacing.md },
  summaryLabel: { fontSize: 12, fontWeight: '600', color: colors.textMuted },
  summaryVal: { fontSize: 20, fontWeight: '800', marginTop: 4 },
  tabs: { flexDirection: 'row', gap: 6, marginTop: spacing.md },
  tab: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999, backgroundColor: colors.bg },
  tabActive: { backgroundColor: colors.primary },
  tabText: { fontSize: 13, fontWeight: '600', color: colors.textMuted },
  tabTextActive: { color: colors.white },
  debtCard: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm },
  debtPhone: { fontSize: 16, fontWeight: '700', color: colors.text },
  debtNote: { fontSize: 13, color: colors.textMuted, marginTop: 2 },
  debtAmount: { fontSize: 18, fontWeight: '800' },
  sum: { fontSize: 12, color: colors.textMuted },
  empty: { alignItems: 'center', marginTop: 80, gap: 12 },
  emptyText: { color: colors.textMuted, fontSize: 15 },
  fab: { position: 'absolute', right: 20, width: 60, height: 60, borderRadius: 30, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center', shadowColor: '#000', shadowOpacity: 0.2, shadowRadius: 8, shadowOffset: { width: 0, height: 4 }, elevation: 6 },
  fabText: { color: colors.white, fontSize: 32, fontWeight: '300', marginTop: -2 },
});
