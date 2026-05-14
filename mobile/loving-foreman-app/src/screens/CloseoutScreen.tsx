import React from 'react';
import { Text, View } from 'react-native';
import type { WorkOrderDetail } from '@/data/contracts';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export interface CloseoutViewModel {
  workOrder: WorkOrderDetail;
  canSubmit: boolean;
  disabledReason?: string;
}

export function CloseoutScreen({ vm }: { vm: CloseoutViewModel }) {
  return (
    <ScreenShell title="Closeout" subtitle="Final photos, material confirmation, incomplete items, queued sync.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Can submit: {vm.canSubmit ? 'Yes' : 'No'}</Text>
        {vm.disabledReason ? <Text style={baseStyles.meta}>Disabled reason: {vm.disabledReason}</Text> : null}
      </View>
    </ScreenShell>
  );
}
