import React from 'react';
import { Text, View } from 'react-native';
import { ScreenShell } from '@/components/ScreenShell';
import { FieldButton } from '@/components/FieldButton';
import { baseStyles } from '@/design/theme';

export interface LanguageSelectionViewModel {
  selectedLanguage: 'en' | 'es';
  changeLanguage(language: 'en' | 'es'): void;
}

export function LanguageSelectionScreen({ vm }: { vm: LanguageSelectionViewModel }) {
  return (
    <ScreenShell title="Language Selection" subtitle="Sticky per device/user; changeable later in Settings.">
      <View style={baseStyles.card}>
        <Text style={baseStyles.meta}>No hard-coded foreman or truck data belongs on this screen.</Text>
        <FieldButton label={`English ${vm.selectedLanguage === 'en' ? '(Selected)' : ''}`} onPress={() => vm.changeLanguage('en')} />
        <FieldButton label={`Español ${vm.selectedLanguage === 'es' ? '(Selected)' : ''}`} onPress={() => vm.changeLanguage('es')} />
      </View>
    </ScreenShell>
  );
}
