import React from 'react';
import { Text, View } from 'react-native';
import type { MyDaySummary } from '@/data/contracts';
import { ScreenShell } from '@/components/ScreenShell';
import { StatusBadge } from '@/components/StatusBadge';
import { baseStyles } from '@/design/theme';

export function MyDayScreen({ summary }: { summary: MyDaySummary }) {
  const tone = summary.syncStatus === 'Synced' ? 'synced' : summary.syncStatus === 'Syncing' ? 'syncing' : 'offline';

  return (
    <ScreenShell title="My Day" subtitle="Assigned Service Appointments, Work Orders, weather, GPS, and sync.">
      <View style={baseStyles.card}>
        <StatusBadge label={summary.syncStatus} tone={tone} />
        <Text style={baseStyles.meta}>Appointments: {summary.serviceAppointments.length}</Text>
        <Text style={baseStyles.meta}>GPS stale: {summary.gpsStatus.isStale ? 'Yes' : 'No'}</Text>
        <Text style={baseStyles.meta}>Rippling: {summary.ripplingStatus.clockStatus ?? 'Unknown'}</Text>
      </View>
    </ScreenShell>
  );
}
