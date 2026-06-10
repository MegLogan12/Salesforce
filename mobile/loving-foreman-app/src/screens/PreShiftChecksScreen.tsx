import React from 'react';
import { Text, View } from 'react-native';
import type { WorkOrderDetail } from '@/data/contracts';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export interface PreShiftChecksViewModel {
  workOrder: WorkOrderDetail;
  canStartRoute: boolean;
  disabledReason?: string;
}

export function PreShiftChecksScreen({ vm }: { vm: PreShiftChecksViewModel }) {
  return (
    <ScreenShell title="Pre-Shift Checks" subtitle="Vehicle checklist, loaded checklist, material context, offline-capable.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Line items available for pull validation: {vm.workOrder.lineItems.length}</Text>
        <Text style={baseStyles.meta}>Start route enabled: {vm.canStartRoute ? 'Yes' : 'No'}</Text>
        {vm.disabledReason ? <Text style={baseStyles.meta}>Disabled reason: {vm.disabledReason}</Text> : null}
      </View>
    </ScreenShell>
  );
}
