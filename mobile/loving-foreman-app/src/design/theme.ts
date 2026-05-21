import { StyleSheet } from 'react-native';
import { tokens } from '@/design/tokens';

export const baseStyles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: tokens.color.background,
    padding: tokens.spacing.lg
  },
  card: {
    backgroundColor: tokens.color.card,
    borderRadius: tokens.radius.card,
    padding: tokens.spacing.lg,
    marginBottom: tokens.spacing.md
  },
  title: {
    color: tokens.color.navy,
    fontSize: tokens.typography.titleSize,
    fontWeight: '700'
  },
  sectionTitle: {
    color: tokens.color.navy,
    fontSize: tokens.typography.sectionSize,
    fontWeight: '700'
  },
  meta: {
    color: tokens.color.grayText,
    fontSize: tokens.typography.metaSize
  }
});
