import React from 'react';
import { Tabs } from 'expo-router';
import { Text } from 'react-native';
import { useI18n } from '../../src/i18n';
import { colors } from '../../src/theme';

function Icon({ label, focused }) {
  return <Text style={{ fontSize: 20, opacity: focused ? 1 : 0.5 }}>{label}</Text>;
}

export default function TabsLayout() {
  const { t } = useI18n();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarStyle: { borderTopColor: colors.border, height: 60, paddingBottom: 8, paddingTop: 6 },
        tabBarLabelStyle: { fontSize: 12, fontWeight: '600' },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: t('debts'), tabBarIcon: ({ focused }) => <Icon label="💵" focused={focused} /> }}
      />
      <Tabs.Screen
        name="profile"
        options={{ title: t('profile'), tabBarIcon: ({ focused }) => <Icon label="👤" focused={focused} /> }}
      />
    </Tabs>
  );
}
