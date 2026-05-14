import React from 'react';
import { Text, View } from 'react-native';
import type { WorkOrderDetail } from '@/data/contracts';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export function ActiveJobScreen({ workOrder }: { workOrder: WorkOrderDetail }) {
  return (
    <ScreenShell title="Active Job" subtitle="Line items, checklists, notes, progress photos, issue flag.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Work order: {workOrder.workOrderNumber}</Text>
        <Text style={baseStyles.meta}>Line items: {workOrder.lineItems.length}</Text>
        <Text style={baseStyles.meta}>Checklist groups: {workOrder.checklistGroups.length}</Text>
      </View>
    </ScreenShell>
  );
}
