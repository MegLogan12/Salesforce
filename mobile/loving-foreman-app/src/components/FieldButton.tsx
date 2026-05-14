import React from 'react';
import { Pressable, Text } from 'react-native';
import { tokens } from '@/design/tokens';

interface FieldButtonProps {
  label: string;
  disabled?: boolean;
  onPress?: () => void;
}

export function FieldButton({ label, disabled, onPress }: FieldButtonProps) {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={{
        backgroundColor: disabled ? tokens.color.border : tokens.color.salesforceBlue,
        borderRadius: tokens.radius.button,
        paddingVertical: tokens.spacing.md,
        paddingHorizontal: tokens.spacing.lg,
        marginTop: tokens.spacing.sm
      }}
    >
      <Text style={{ color: '#ffffff', textAlign: 'center', fontSize: tokens.typography.buttonSize, fontWeight: '700' }}>
        {label}
      </Text>
    </Pressable>
  );
}
