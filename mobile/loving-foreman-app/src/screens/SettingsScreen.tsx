import React from 'react';
import { Text, View } from 'react-native';
import { ScreenShell } from '@/components/ScreenShell';
import { baseStyles } from '@/design/theme';

export function SettingsScreen() {
  return (
    <ScreenShell title="Settings" subtitle="Language, sync support, map provider, and device/session help.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>Contains language change entry point and support actions.</Text>
      </View>
    </ScreenShell>
  );
}
