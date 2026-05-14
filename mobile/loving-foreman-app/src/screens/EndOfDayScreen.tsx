import React from 'react';
import { Text, View } from 'react-native';
import type { RipplingStatus, SyncStatus } from '@/data/contracts';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export function EndOfDayScreen({
  completedJobs,
  pendingSyncCount,
  ripplingStatus,
  syncStatus
}: {
  completedJobs: number;
  pendingSyncCount: number;
  ripplingStatus: RipplingStatus;
  syncStatus: SyncStatus;
}) {
  return (
    <ScreenShell title="End of Day" subtitle="Rippling display only. No lunch or clock-out buttons.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Completed jobs: {completedJobs}</Text>
        <Text style={baseStyles.meta}>Pending sync: {pendingSyncCount}</Text>
        <Text style={baseStyles.meta}>Rippling: {ripplingStatus.clockStatus ?? 'Unknown'}</Text>
        <Text style={baseStyles.meta}>Sync status: {syncStatus}</Text>
      </View>
    </ScreenShell>
  );
}
