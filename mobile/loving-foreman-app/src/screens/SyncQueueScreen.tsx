import React from 'react';
import { Text, View } from 'react-native';
import type { OfflineQueueItem } from '@/offline/types';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export function SyncQueueScreen({ items }: { items: OfflineQueueItem[] }) {
  return (
    <ScreenShell title="Sync Queue" subtitle="Pending items, retry, failed states, and conflicts.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Queue items: {items.length}</Text>
      </View>
    </ScreenShell>
  );
}
