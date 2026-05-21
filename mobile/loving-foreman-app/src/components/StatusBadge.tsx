import React from 'react';
import { Text, View } from 'react-native';
import { tokens } from '@/design/tokens';

interface StatusBadgeProps {
  label: string;
  tone: 'offline' | 'syncing' | 'synced';
}

export function StatusBadge({ label, tone }: StatusBadgeProps) {
  const backgroundColor =
    tone === 'offline'
      ? tokens.color.badgeOffline
      : tone === 'syncing'
        ? tokens.color.badgeSyncing
        : tokens.color.badgeSynced;

  return (
    <View
      style={{
        backgroundColor,
        borderRadius: tokens.radius.badge,
        paddingHorizontal: tokens.spacing.md,
        paddingVertical: tokens.spacing.xs,
        alignSelf: 'flex-start'
      }}
    >
      <Text style={{ color: '#ffffff', fontWeight: '700' }}>{label}</Text>
    </View>
  );
}
