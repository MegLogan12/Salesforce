import React from 'react';
import { Text, View } from 'react-native';
import type { GpsStatus, ServiceAppointmentSummary } from '@/data/contracts';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export function RouteNavigationScreen({
  appointment,
  gpsStatus
}: {
  appointment: ServiceAppointmentSummary;
  gpsStatus: GpsStatus;
}) {
  return (
    <ScreenShell title="Route / Navigation" subtitle="Native map handoff only. No fake route lines or ETA.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Next stop: {appointment.appointmentNumber}</Text>
        <Text style={baseStyles.meta}>Address: {appointment.addressLine ?? 'Missing'}</Text>
        <Text style={baseStyles.meta}>Truck: {gpsStatus.truckLabel ?? 'Unassigned'}</Text>
      </View>
    </ScreenShell>
  );
}
