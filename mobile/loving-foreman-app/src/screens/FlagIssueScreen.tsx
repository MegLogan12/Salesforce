import React from 'react';
import { Text, View } from 'react-native';
import type { IssueDraft } from '@/data/contracts';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export function FlagIssueScreen({ draft }: { draft: IssueDraft }) {
  return (
    <ScreenShell title="Flag Issue" subtitle="Always available replacement for the removed 2 PM Health Check.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Issue type: {draft.issueType}</Text>
        <Text style={baseStyles.meta}>Impacted line items: {draft.impactedLineItemIds.length}</Text>
        <Text style={baseStyles.meta}>Photos queued: {draft.photoQueueIds.length}</Text>
      </View>
    </ScreenShell>
  );
}
