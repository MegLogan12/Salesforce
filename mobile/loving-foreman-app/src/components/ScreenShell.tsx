import React, { PropsWithChildren } from 'react';
import { SafeAreaView, Text, View } from 'react-native';
import { baseStyles } from '@/design/theme';

interface ScreenShellProps extends PropsWithChildren {
  title: string;
  subtitle?: string;
}

export function ScreenShell({ title, subtitle, children }: ScreenShellProps) {
  return (
    <SafeAreaView style={baseStyles.screen}>
      <View style={baseStyles.card}>
        <Text style={baseStyles.title}>{title}</Text>
        {subtitle ? <Text style={baseStyles.meta}>{subtitle}</Text> : null}
      </View>
      {children}
    </SafeAreaView>
  );
}
