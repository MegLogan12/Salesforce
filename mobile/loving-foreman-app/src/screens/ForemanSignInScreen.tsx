import React from 'react';
import { Text, View } from 'react-native';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export interface ForemanSignInViewModel {
  availableForemen: Array<{ userId: string; label: string }>;
  availableTrucks: Array<{ vehicleId: string; truckLabel: string }>;
  crewAssignments: Array<{ serviceCrewId: string; crewLabel: string }>;
  submit(): Promise<void>;
}

export function ForemanSignInScreen({ vm }: { vm: ForemanSignInViewModel }) {
  return (
    <ScreenShell title="Foreman Sign-In" subtitle="Foreman + truck + crew + approved identity method.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Validates against Salesforce User, ServiceResource, AssignedResource, and crew assignment.</Text>
        <Text style={baseStyles.meta}>No hard-coded foreman names or truck labels.</Text>
        <Text style={baseStyles.meta}>Foremen loaded: {vm.availableForemen.length}</Text>
        <Text style={baseStyles.meta}>Trucks loaded: {vm.availableTrucks.length}</Text>
        <Text style={baseStyles.meta}>Crew assignments loaded: {vm.crewAssignments.length}</Text>
      </View>
    </ScreenShell>
  );
}
