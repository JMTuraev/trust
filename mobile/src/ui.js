import React from 'react';
import {
  Text, TextInput, TouchableOpacity, View, ActivityIndicator, StyleSheet,
} from 'react-native';
import { colors, radius, spacing } from './theme';

export function Button({ title, onPress, loading, disabled, variant = 'primary', style }) {
  const bg =
    variant === 'primary' ? colors.primary :
    variant === 'danger' ? colors.red :
    variant === 'ghost' ? 'transparent' : colors.primary;
  const txt = variant === 'ghost' ? colors.primary : colors.white;
  return (
    <TouchableOpacity
      activeOpacity={0.85}
      onPress={onPress}
      disabled={disabled || loading}
      style={[
        s.btn,
        { backgroundColor: bg, opacity: disabled ? 0.5 : 1,
          borderWidth: variant === 'ghost' ? 1.5 : 0, borderColor: colors.primary },
        style,
      ]}
    >
      {loading ? <ActivityIndicator color={txt} /> :
        <Text style={[s.btnText, { color: txt }]}>{title}</Text>}
    </TouchableOpacity>
  );
}

export function Field({ label, ...props }) {
  return (
    <View style={{ marginBottom: spacing.md }}>
      {label ? <Text style={s.label}>{label}</Text> : null}
      <TextInput
        placeholderTextColor={colors.textMuted}
        style={s.input}
        {...props}
      />
    </View>
  );
}

export function Card({ children, style, onPress }) {
  const Wrap = onPress ? TouchableOpacity : View;
  return (
    <Wrap activeOpacity={0.9} onPress={onPress} style={[s.card, style]}>
      {children}
    </Wrap>
  );
}

export function Badge({ text, color = colors.primary, bg = colors.primaryLight }) {
  return (
    <View style={[s.badge, { backgroundColor: bg }]}>
      <Text style={[s.badgeText, { color }]}>{text}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  btn: {
    height: 54, borderRadius: radius.md, alignItems: 'center',
    justifyContent: 'center', paddingHorizontal: spacing.lg,
  },
  btnText: { fontSize: 16, fontWeight: '700' },
  label: { fontSize: 13, fontWeight: '600', color: colors.textMuted, marginBottom: 6 },
  input: {
    height: 54, borderWidth: 1.5, borderColor: colors.border, borderRadius: radius.md,
    paddingHorizontal: spacing.md, fontSize: 16, color: colors.text,
    backgroundColor: colors.white,
  },
  card: {
    backgroundColor: colors.card, borderRadius: radius.lg, padding: spacing.md,
    borderWidth: 1, borderColor: colors.border,
  },
  badge: { paddingHorizontal: 10, paddingVertical: 4, borderRadius: 999, alignSelf: 'flex-start' },
  badgeText: { fontSize: 12, fontWeight: '700' },
});
