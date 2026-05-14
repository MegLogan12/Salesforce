import React from 'react';
import { Text, View } from 'react-native';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export interface ArrivalViewModel {
  geofenceAvailable: boolean;
  manualConfirmAllowed: boolean;
  requiredPhotoCategories: string[];
}

export function ArrivalScreen({ vm }: { vm: ArrivalViewModel }) {
  return (
    <ScreenShell title="Arrival" subtitle="Geofence when available; manual confirm when needed.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Geofence available: {vm.geofenceAvailable ? 'Yes' : 'No'}</Text>
        <Text style={baseStyles.meta}>Manual confirm allowed: {vm.manualConfirmAllowed ? 'Yes' : 'No'}</Text>
        <Text style={baseStyles.meta}>Required photos: {vm.requiredPhotoCategories.join(', ')}</Text>
      </View>
    </ScreenShell>
  );
}
